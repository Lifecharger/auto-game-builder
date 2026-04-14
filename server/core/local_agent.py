"""Local AI agent orchestrator — runs Aider+Ollama with smart context selection."""

import os
import re
import subprocess
import glob
from typing import Optional


# Max tokens budget (leave room for model response)
MAX_CONTEXT_TOKENS = 10000  # ~10K tokens for context, rest for response
CHARS_PER_TOKEN = 4  # rough estimate
MAX_CONTEXT_CHARS = MAX_CONTEXT_TOKENS * CHARS_PER_TOKEN


def run_local_task(
    task: str,
    project_path: str,
    aider_path: str = "aider",
    model: str = "ollama/qwen2.5-coder:7b",
    timeout: int = 600,
    ollama_url: str = "http://localhost:11434",
) -> tuple[int, str]:
    """
    Run a task using local AI (Aider + Ollama).
    Automatically finds relevant files and builds compact context.
    """
    # Step 1: Find relevant files based on task keywords
    relevant_files = _find_relevant_files(task, project_path)

    # Step 2: Build compact context from project
    context_file = os.path.join(project_path, ".local_context.md")
    _build_context(project_path, context_file)

    # Step 3: Build aider command (--no-pretty --no-fancy-input for headless/non-TTY)
    cmd = [
        aider_path,
        "--model", model,
        "--message", task,
        "--yes-always",
        "--no-git",
        "--no-show-release-notes",
        "--no-show-model-warnings",
        "--no-pretty",
        "--no-fancy-input",
    ]

    # Add context file as read-only if it exists and is small
    if os.path.isfile(context_file):
        size = os.path.getsize(context_file)
        if size < 2000:  # ~500 tokens max for context
            cmd.extend(["--read", context_file])

    # Add relevant files (limit to 3 files to stay within context)
    for f in relevant_files[:3]:
        cmd.append(f)

    # Step 4: Run
    try:
        env = {**os.environ, "OLLAMA_API_BASE": ollama_url}
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=project_path,
            env=env,
        )
        stdout, _ = process.communicate(timeout=timeout)
        return process.returncode, stdout or ""
    except subprocess.TimeoutExpired:
        process.kill()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        return -1, "Timeout"
    except Exception as e:
        return -2, str(e)


def _find_relevant_files(task: str, project_path: str) -> list[str]:
    """Find files relevant to the task using keyword matching."""
    # Extract keywords from task (ignore common words)
    stop_words = {
        'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
        'has', 'have', 'had', 'do', 'does', 'did', 'will', 'would',
        'could', 'should', 'may', 'might', 'can', 'this', 'that',
        'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of',
        'with', 'it', 'not', 'from', 'by', 'as', 'if', 'so', 'no',
        'add', 'fix', 'change', 'update', 'make', 'create', 'remove',
        'please', 'file', 'code', 'app', 'project',
    }
    words = re.findall(r'[a-zA-Z_]\w+', task.lower())
    keywords = [w for w in words if w not in stop_words and len(w) > 2]

    if not keywords:
        keywords = words[:5]

    # Search for files containing these keywords
    scored_files: dict[str, int] = {}
    code_extensions = {'.dart', '.py', '.gd', '.yaml', '.toml', '.cfg', '.json', '.xml'}

    for root, dirs, files in os.walk(project_path):
        # Skip build/hidden/generated directories
        dirs[:] = [d for d in dirs if d not in {
            '.git', '.dart_tool', 'build', 'node_modules', '.godot',
            '__pycache__', '.gradle', 'android', 'ios', 'web', 'linux',
            'macos', 'windows', '.import',
        }]

        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in code_extensions:
                continue

            filepath = os.path.join(root, fname)
            rel_path = os.path.relpath(filepath, project_path)

            # Score by filename match
            score = 0
            fname_lower = fname.lower()
            for kw in keywords:
                if kw in fname_lower:
                    score += 10

            # Score by content match (quick scan first 5KB)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read(5000).lower()
                for kw in keywords:
                    score += content.count(kw)
            except Exception:
                pass

            if score > 0:
                # Penalize large files
                try:
                    size = os.path.getsize(filepath)
                    if size > MAX_CONTEXT_CHARS:
                        score = max(1, score // 2)
                except Exception:
                    pass
                scored_files[rel_path] = score

    # Sort by score, return top matches
    sorted_files = sorted(scored_files.items(), key=lambda x: -x[1])
    return [f for f, _ in sorted_files[:5]]


def _build_context(project_path: str, output_path: str):
    """Build a tiny context file from project structure."""
    lines = []

    # Project type detection
    if os.path.isfile(os.path.join(project_path, "pubspec.yaml")):
        lines.append("Flutter/Dart project")
        # Read app name from pubspec
        try:
            with open(os.path.join(project_path, "pubspec.yaml"), 'r', encoding='utf-8') as f:
                for line in f:
                    if line.startswith("name:"):
                        lines.append(f"App: {line.split(':')[1].strip()}")
                        break
        except Exception:
            pass
    elif os.path.isfile(os.path.join(project_path, "project.godot")):
        lines.append("Godot project")
    elif os.path.isfile(os.path.join(project_path, "requirements.txt")):
        lines.append("Python project")

    # Key folders
    lib_path = os.path.join(project_path, "lib")
    if os.path.isdir(lib_path):
        folders = [d for d in os.listdir(lib_path) if os.path.isdir(os.path.join(lib_path, d))]
        if folders:
            lines.append(f"Structure: lib/{', lib/'.join(sorted(folders))}")

    # Read CLAUDE.md if tiny
    claude_md = os.path.join(project_path, "CLAUDE.md")
    if os.path.isfile(claude_md):
        try:
            with open(claude_md, 'r', encoding='utf-8') as f:
                content = f.read(500)  # first 500 chars only
            if content.strip():
                lines.append(f"Notes: {content.strip()[:300]}")
        except Exception:
            pass

    # Write context
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    except Exception:
        pass

"""Wrappers for AI CLI tools: Claude, Gemini, Codex, Local (Aider+Ollama)."""

import subprocess
import os
from typing import Callable, Optional


class AITools:
    def __init__(self, settings: dict):
        self.settings = settings

    def run_local(
        self,
        prompt: str,
        project_path: str,
        on_output: Optional[Callable[[str], None]] = None,
        timeout: int = 600,
    ) -> tuple[int, str]:
        """Run Aider + Ollama (local LLM) with smart context selection."""
        from core.local_agent import run_local_task
        aider_path = self.settings.get("aider_path", "") or "aider"
        model = self.settings.get("local_model", "ollama/qwen2.5-coder:7b")
        ollama_url = self.settings.get("ollama_url", "http://localhost:11434")
        return run_local_task(prompt, project_path, aider_path, model, timeout, ollama_url)

    def run_claude(
        self,
        prompt: str,
        project_path: str,
        mcp_config: str = "",
        on_output: Optional[Callable[[str], None]] = None,
        timeout: int = 1200,
    ) -> tuple[int, str]:
        """Run Claude CLI in print mode. Returns (exit_code, full_output)."""
        claude_path = self.settings.get("claude_path", "claude")
        cmd = [
            claude_path, "-p",
            "--dangerously-skip-permissions",
            "--verbose",
            "--add-dir", project_path,
        ]
        if mcp_config and os.path.isfile(mcp_config):
            cmd.extend(["--mcp-config", mcp_config])

        return self._run_subprocess(cmd, prompt, project_path, on_output, timeout)

    def run_codex(
        self,
        prompt: str,
        project_path: str,
        on_output: Optional[Callable[[str], None]] = None,
        timeout: int = 1200,
    ) -> tuple[int, str]:
        """Run Codex CLI. Returns (exit_code, full_output)."""
        codex_path = self.settings.get("codex_path", "codex")
        cmd = [codex_path, "exec", "--full-auto", "-C", project_path, prompt]
        return self._run_subprocess(cmd, None, project_path, on_output, timeout)

    def run_gemini(
        self,
        prompt: str,
        project_path: str = "",
        on_output: Optional[Callable[[str], None]] = None,
        timeout: int = 600,
    ) -> tuple[int, str]:
        """Run Gemini CLI in headless mode. Returns (exit_code, full_output)."""
        gemini_path = self.settings.get("gemini_path", "gemini")
        cmd = [gemini_path, "-p", "--sandbox=off", prompt]
        cwd = project_path if project_path and os.path.isdir(project_path) else None
        env_extra = {"GEMINI_NO_EXTENSIONS": "1"}
        return self._run_subprocess(cmd, None, cwd, on_output, timeout, env_extra)

    def _run_subprocess(
        self,
        cmd: list[str],
        stdin_text: Optional[str],
        cwd: Optional[str],
        on_output: Optional[Callable[[str], None]],
        timeout: int,
        env_extra: Optional[dict[str, str]] = None,
    ) -> tuple[int, str]:
        """Run a subprocess, stream output byte-by-byte for real-time logging."""
        output_chunks = []
        try:
            # Use unbuffered binary mode + manual line reading for real-time output
            env = {**os.environ, "PYTHONUNBUFFERED": "1"}
            if env_extra:
                env.update(env_extra)
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE if stdin_text else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=cwd,
                env=env,
                bufsize=0,  # unbuffered
            )

            if stdin_text:
                process.stdin.write(stdin_text.encode("utf-8"))
                process.stdin.close()

            # Read byte-by-byte to defeat buffering, accumulate lines
            current_line = b""
            import time
            start = time.time()
            while True:
                if timeout and (time.time() - start) > timeout:
                    process.kill()
                    try:
                        process.wait(timeout=10)
                    except Exception:
                        pass
                    output_chunks.append(current_line.decode("utf-8", errors="replace"))
                    return -1, "".join(output_chunks) + "\n[TIMEOUT]"

                byte = process.stdout.read(1)
                if not byte:
                    # Process ended
                    if current_line:
                        line = current_line.decode("utf-8", errors="replace")
                        output_chunks.append(line)
                        if on_output:
                            on_output(line.rstrip("\n\r"))
                    break

                if byte in (b"\n", b"\r"):
                    if current_line:
                        line = current_line.decode("utf-8", errors="replace")
                        output_chunks.append(line + "\n")
                        if on_output:
                            on_output(line)
                        current_line = b""
                else:
                    current_line += byte

            process.wait(timeout=30)
            return process.returncode, "".join(output_chunks)

        except FileNotFoundError:
            return -2, f"Command not found: {cmd[0]}"
        except Exception as e:
            return -3, f"Error: {e}"

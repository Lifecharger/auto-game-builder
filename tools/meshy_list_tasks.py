"""
Meshy AI — List tasks across all endpoints

Usage:
  python meshy_list_tasks.py                    # List all task types
  python meshy_list_tasks.py text-to-3d         # Specific type
  python meshy_list_tasks.py image-to-3d --page 2 --size 20
"""

import argparse
import json
from meshy_client import get

ENDPOINTS = {
    "text-to-3d": "/openapi/v2/text-to-3d",
    "image-to-3d": "/openapi/v1/image-to-3d",
    "multi-image-to-3d": "/openapi/v1/multi-image-to-3d",
    "retexture": "/openapi/v1/retexture",
    "text-to-texture": "/openapi/v1/text-to-texture",
    "remesh": "/openapi/v1/remesh",
    "text-to-image": "/openapi/v1/text-to-image",
    "image-to-image": "/openapi/v1/image-to-image",
}


def list_tasks(endpoint: str, page: int, size: int):
    params = {"page_num": page, "page_size": size, "sort_by": "-created_at"}
    try:
        tasks = get(endpoint, params)
        if not isinstance(tasks, list):
            tasks = tasks.get("results", tasks.get("data", []))
        return tasks
    except SystemExit:
        return []


def print_task(task):
    tid = task.get("id", "?")
    status = task.get("status", "?")
    progress = task.get("progress", 0)
    prompt = task.get("prompt", "")[:60]
    ttype = task.get("type", "?")
    has_textures = bool(task.get("texture_urls"))
    tex_marker = " [TEX]" if has_textures else ""
    print(f"  {tid}  {status:12s} {progress:3d}%  {ttype:25s}{tex_marker}  {prompt}")


def main():
    parser = argparse.ArgumentParser(description="Meshy List Tasks")
    parser.add_argument("type", nargs="?", choices=list(ENDPOINTS.keys()), help="Task type to list")
    parser.add_argument("--page", type=int, default=1)
    parser.add_argument("--size", type=int, default=10)
    parser.add_argument("--json", action="store_true", help="Output raw JSON")

    args = parser.parse_args()

    types = [args.type] if args.type else list(ENDPOINTS.keys())

    for t in types:
        endpoint = ENDPOINTS[t]
        tasks = list_tasks(endpoint, args.page, args.size)
        if not tasks:
            continue

        print(f"\n=== {t.upper()} ({len(tasks)} tasks) ===")
        if args.json:
            print(json.dumps(tasks, indent=2))
        else:
            for task in tasks:
                print_task(task)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Хук Claude Code: после правки .gd-файла проверяет его парсером Godot (~0,4 с).

Молчит, если ошибок нет. При ошибке выводит до 10 строк SCRIPT ERROR и
возвращает код 2 — Claude видит их сразу и исправляет.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MAX_LINES = 10


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    if not file_path.endswith(".gd"):
        return 0
    path = Path(file_path).resolve()
    if ROOT not in path.parents or not path.exists():
        return 0
    relative = path.relative_to(ROOT).as_posix()
    if relative.startswith(("addons/", ".godot/")):
        return 0
    environment = os.environ.copy()
    environment["XDG_CONFIG_HOME"] = str(ROOT / ".godot" / "local-config")
    environment["XDG_DATA_HOME"] = str(ROOT / ".godot" / "local-data")
    try:
        result = subprocess.run(
            ["godot", "--headless", "--path", str(ROOT), "--check-only", "-s", f"res://{relative}"],
            cwd=ROOT, env=environment, text=True, timeout=60,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except (OSError, subprocess.TimeoutExpired):
        return 0
    errors = [line.strip() for line in result.stdout.splitlines() if "SCRIPT ERROR" in line]
    if result.returncode == 0 and not errors:
        return 0
    if not errors:
        errors = [line.strip() for line in result.stdout.splitlines() if "ERROR" in line]
    print(f"Godot --check-only: ошибки в {relative}", file=sys.stderr)
    for line in errors[:MAX_LINES]:
        print(line, file=sys.stderr)
    if len(errors) > MAX_LINES:
        print(f"... и ещё {len(errors) - MAX_LINES}", file=sys.stderr)
    print("Подсказка: новый class_name виден только после `godot --headless --path . --import`.",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())

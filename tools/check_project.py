#!/usr/bin/env python3
"""Импорт, GUT, smoke и запуск; ловит ошибки скриптов даже при коде выхода Godot 0.

Запуск из проекта: python3 -I tools/check_project.py
Логи: .godot/checks/. Godot user-data остаётся внутри проекта.
"""
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run_stage(name: str, arguments: list[str], environment: dict[str, str]) -> bool:
    command = ["godot", "--headless", "--path", str(ROOT), *arguments]
    log_path = ROOT / ".godot" / "checks" / f"{name}.txt"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    except (OSError, subprocess.TimeoutExpired) as error:
        log_path.write_text(str(error), encoding="utf-8")
        print(f"{name}: ОШИБКА — {error}", flush=True)
        return False
    output = ANSI.sub("", result.stdout)
    log_path.write_text(output, encoding="utf-8")
    errors = [line for line in output.splitlines() if "ERROR:" in line]
    if name == "import":
        # В ограниченной среде редактор не может открыть локальный TCP-сокет.
        errors = [line for line in errors if line not in (
            'ERROR: Condition "_sock == -1" is true. Returning: FAILED',
            'ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE')]
    passed = result.returncode == 0 and not errors
    if name == "gut":
        passed = passed and "All tests passed!" in output and "Ignoring script" not in output
    if name in ("smoke", "lessons"):
        passed = passed and "SMOKE:" in output
    print(f"{name}: {'OK' if passed else 'ОШИБКА'} — {log_path.relative_to(ROOT)}", flush=True)
    if name == "gut":
        for line in output.splitlines():
            if re.match(r"(Tests|Passing Tests|Failing Tests|Asserts)\s", line):
                print(f"  {line}", flush=True)
    if not passed:
        print("\n".join(output.splitlines()[-25:]), flush=True)
    return passed


def main() -> int:
    environment = os.environ.copy()
    environment.update(XDG_CONFIG_HOME=str(ROOT / ".godot" / "local-config"),
                       XDG_DATA_HOME=str(ROOT / ".godot" / "local-data"))
    stages = [
        ("import", ["--editor", "--quit"]),
        ("gut", ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"]),
        ("smoke", ["-s", "res://tools/rework_smoke.gd"]),
        ("lessons", ["-s", "res://tools/reaction_lab_smoke.gd"]),
        ("launch", ["--quit-after", "2"]),
    ]
    for name, arguments in stages:
        if not run_stage(name, arguments, environment):
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

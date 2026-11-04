#!/bin/sh
# Модели из сеток Hunyuan3D: tools/blender/noir/h3d.sh <id> ... [--tex 4096] [--no-export] (по процессу на модель)
B=${BLENDER:-/home/d0nco/.local/share/Steam/steamapps/common/Blender/blender}
cd "$(dirname "$0")/../../.." || exit 1
for a in "$@"; do
  case "$a" in --*|[0-9]*) continue;; esac
  opts=$(printf '%s\n' "$@" | grep -E '^(--|[0-9])' | tr '\n' ' ')
  # flock: Blender-процессы строго по одному, даже если обёртку запустили дважды
  flock output/.h3d_blender.lock "$B" -b --factory-startup -P tools/blender/noir/h3d.py -- "$a" $opts 2>&1 | grep -E "^\[(h3d|fit)\]|Error|Traceback|line [0-9]+" | grep -v "^\[fit\] pass [01]"
done

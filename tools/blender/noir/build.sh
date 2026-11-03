#!/bin/sh
# Построить модели и собрать сравнения: tools/blender/noir/build.sh <id> ... [--no-export]
B=${BLENDER:-/home/d0nco/.local/share/Steam/steamapps/common/Blender/blender}
cd "$(dirname "$0")/../../.." || exit 1
"$B" -b --factory-startup -P tools/blender/noir/run.py -- "$@" 2>&1 | grep -E "^\[noir\]|Error|Traceback|line [0-9]+" 
ids=$(printf '%s\n' "$@" | grep -v '^--')
python3 -I tools/blender/noir/compare.py $ids

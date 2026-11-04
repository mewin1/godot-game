#!/bin/sh
# Слабые модели: другие сиды Hunyuan3D, остаётся сетка с лучшим IoU силуэта.
# tools/blender/noir/h3d_retry.sh <группа> <id> [<id> ...]   (сиды: 16 — исходный, 7, 42)
cd "$(dirname "$0")/../../.." || exit 1
R=source_art/noir_h3d/raw
I=new_concept/compare/renders
group=$1; shift
for id in "$@"; do
  [ -f $R/${id}_s16.glb ] || cp $R/$id.glb $R/${id}_s16.glb
  best=16; best_iou=$(cat $I/${id}_h3d.iou 2>/dev/null || echo 0)
  for seed in 7 42; do
    python3 -I tools/concepts/h3d_gen.py $group $id --seed $seed > /dev/null || continue
    cp $R/$id.glb $R/${id}_s$seed.glb
    tools/blender/noir/h3d.sh $id --no-export > /dev/null
    iou=$(cat $I/${id}_h3d.iou)
    echo "$id seed $seed: IoU $iou (лучший $best: $best_iou)"
    if [ "$(python3 -c "print(1 if $iou > $best_iou else 0)")" = 1 ]; then best=$seed; best_iou=$iou; fi
  done
  cp $R/${id}_s$best.glb $R/$id.glb
  tools/blender/noir/h3d.sh $id | grep "силуэт"
  echo "$id: оставлен сид $best (IoU $best_iou)"
done

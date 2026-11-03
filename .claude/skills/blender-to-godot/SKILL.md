---
name: blender-to-godot
description: Сделать или обновить 3D-модель в Blender (через Blender MCP) и встроить в Godot — экспорт GLB, материалы, проверка кадром.
---

# Blender → Godot

Образец всего конвейера — лесная арена: `assets/arenas/forest/README.md`
(читать нужный раздел, не целиком).

Раскладка:
- исходник `.blend` → `source_art/<тип>/<имя>.blend`;
- экспорт → `assets/<тип>/<имя>/<имя>.glb` (+ текстуры рядом, README с устройством);
- скрипты построения/экспорта (bpy) → `tools/blender/`, перезапускаемые: модель строится кодом.

Экспорт (`bpy.ops.export_scene.gltf`): только нужные меши `use_selection=True`,
без камер и света; с вершинным цветом — `export_vertex_color='ACTIVE'`;
если материал подменяется в Godot — `export_image_format='NONE'`.
Масштаб: 1 единица = 1 м, клетка поля 2 м; ось Y в Godot вверх (экспортёр сам переводит Z-up).

В Godot:
1. `godot --headless --path . --import` (с XDG-префиксом).
2. Материалы, которые Godot рисует неверно, подменять своим `.tres` через
   `_subresources` в `<имя>.glb.import`.
3. Кадр: превью-сцена или `tools/capture_match.gd` (см. скилл godot-look); рядом — рендер Blender.

Экономия контекста: из Blender MCP брать короткие ответы (имена, счётчики, габариты),
скриншот вьюпорта — один на шаг. GLB > 20 МиБ или > 300k треугольников — сказать автору.

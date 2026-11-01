# Проба 2.5D — 1 ноября 2026

Отдельная художественная сцена `scenes/visual_slice.tscn`.
Открывается кнопкой «Проба графики 2.5D» слева сверху в главном меню.
Две постройки выбираются в лавке и на поле, один боец движется по дороге,
кнопка паузы останавливает его. Это визуальная демонстрация, без боевой симуляции,
покупок и изменения действующих правил. Основной матч сохраняет предыдущий вид.

Графика: встроенный imagegen, режим генерации. Слои сохранены в
`assets/visual_slice/`. Окружение — единая иллюстрация, постройки и боец —
отдельные изображения с прозрачностью. Путь и сетка фона предназначены только
для этой художественной пробы; не являются заменой BoardLayout основного матча.
Перенос стиля в матч требует модульного поля, согласованного с настоящей сеткой.

## Промпты

### Окружение

Create a production game background plate, landscape 1536x1024. Reference is
the attached FIRST image (dark fantasy tower defense courtyard), NOT the white
wireframe. Match its exquisite hand-painted realistic game illustration style,
dusk blue stone and warm amber braziers. NO UI, NO text, NO towers, NO soldiers.
Orthographic 2.5D view, camera from above at 60 degrees, no diamond isometric
rotation: grid horizontal lines stay horizontal, vertical grid lines stay vertical.
Central rectangular stone courtyard occupying x 8%-92%, y 16%-88%, a perfectly
regular 8 columns by 7 rows rectangular grid of worn blue-grey flagstones with thin
brass seams. A pale warm sandstone walking road turns in an S across the courtyard
through its middle, from left edge at 38% height, right along row then down at
middle, then right to right edge at 74% height. Perimeter low detailed fortress
walls, four fire braziers, dark pines and rocky cliff surround with blue mist.
Keep center unobstructed and sufficiently bright. Rich stone microtexture,
convincing ambient occlusion, warm pools of flame light, refined game art.
This is a usable environment layer, no buildings on playable tiles. Fill entire canvas.

### Ледяная башня

Use case: stylized-concept. Production sprite for a 2.5D dark fantasy tower defense
game, matching richly detailed painted realistic medieval game art, cold blue dusk
and amber highlights. ONE isolated ice tower, full object entirely visible,
transparent background. Square canvas. Orthographic elevated camera at 60 degrees
downwards, FRONT view with visible right side and top, no diamond floor tile.
Tall glowing cyan crystal cluster mounted on a blackened iron and dark grey stone
square fortified plinth, delicate brass trim, gothic iron ribs, frost crystals at
foot. Strong readable silhouette. The tower occupies central 75% width and 85%
height, base centered at bottom with small margin. Cool moonlight upper left,
warm amber rim from lower left, detailed worn rock/metal textures. This is a
finished small game sprite, clean alpha edges, no text, no UI, no scene, no
floating particles far outside silhouette, no cast shadow beyond object.

### Орудие

Production game sprite, ONE isolated medieval bronze cannon on dark oak carriage
and square dark stone plinth, entire object on transparent background. Richly
detailed realistic painterly fantasy game art matching a blue dusk fortress
courtyard lit by amber braziers. Orthographic elevated camera 60 degrees down,
view from front with visible right side/top, long dark steel barrel points toward
upper right. Small polished brass fittings, iron bands, dark warm wood, believable
layered plinth. Compact silhouette, occupies 80% canvas, base bottom center.
Cold blue light upper left and amber rim lower left. Crisp readable art at 160px
size. No text, no UI, no floor outside plinth, no characters, no smoke,
no background, no big cast shadow.

### Боец

Production sprite for dark fantasy medieval tower defense. ONE human Slavic
infantry soldier, full body including boots, isolated transparent background,
entire figure centered. Orthographic elevated game camera 60 degrees from above,
three-quarter front view, facing screen right. A sturdy human man wearing iron
conical helmet, chainmail, dark red tunic, leather boots, round dark wooden shield
in left hand and short spear in right hand, taking a walking step. Detailed
realistic painterly game art, not cartoon, not a chibi, human proportions.
Cold blue dusk light from top left, warm subtle amber rim at lower left, worn steel
and muted crimson cloth. Readable silhouette at 80 pixels tall. No ground,
no plinth, no floor, no scene, no text, no UI, no cast shadow.
Leave small transparent margin all around.

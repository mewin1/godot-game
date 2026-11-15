class_name RitualIcons
extends RefCounted
## Знаки «Обряда» одной семьи (critique_4 п. 28, 45, 46, 48): белые силуэты из ComfyUI
## (tools/concepts/icon_gen.py), цвет задаёт место показа. Реакции, усиления, стихии, роли, умения.

const ROOT: String = "res://assets/ui/ritual/icons/%s.png"
## Реакция → знак (у нескольких реакций одно имя и один знак).
const REACTIONS: Dictionary[StringName, String] = {
	&"steam": "rx_steam", &"chain": "rx_chain", &"conservation": "rx_conservation", &"execute": "rx_execute",
	&"freeze": "rx_freeze", &"infection": "rx_infection", &"melt": "rx_melt", &"melt_reverse": "rx_melt",
	&"roast": "rx_roast", &"roast_reverse": "rx_roast", &"shatter": "rx_shatter",
	&"surge": "rx_surge", &"blizzard": "rx_blizzard", &"frozen_wind": "rx_blizzard", &"wildfire": "rx_wildfire"}
## Усиление рассвета → знак; «Слава» стихии берёт знак своей стихии.
const BOONS: Dictionary[StringName, String] = {
	&"merchants": "boon_merchants", &"tar_barrel": "boon_tar", &"rain_bowl": "boon_rain_bowl",
	&"gate_charm": "boon_charm", &"stakes": "boon_stakes", &"craft": "boon_craft", &"strong_gate": "boon_strong_gate",
	&"carpenters": "boon_carpenters", &"keen_eye": "boon_keen_eye", &"vigor": "boon_vigor"}


static var _cache: Dictionary[String, Texture2D] = {}


## Знак по имени файла (без расширения) или null. Отдаётся ImageTexture из картинки: импортированная
## текстура в draw_texture_rect карточек рисовалась сплошным квадратом (альфа терялась), в кнопках — нет.
static func named(icon_id: String) -> Texture2D:
	if _cache.has(icon_id):
		return _cache[icon_id]
	var path: String = ROOT % icon_id
	if not ResourceLoader.exists(path):
		return null
	var image: Image = (load(path) as Texture2D).get_image()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[icon_id] = texture
	return texture


## Знак стихии (упрощённый, читается в 24 px); пустая стихия — null.
static func god(god_id: StringName) -> Texture2D:
	return named("god_%s" % god_id) if god_id != &"" else null


static func reaction(reaction_id: StringName) -> Texture2D:
	var icon_id: String = REACTIONS.get(reaction_id, "rx_steam")
	return named(icon_id)


static func boon(boon_id: StringName, god_id: StringName) -> Texture2D:
	if god_id != &"":
		return god(god_id)
	return named(BOONS[boon_id]) if BOONS.has(boon_id) else named("boon_charm")


## Белый знак на кнопке — цветом color во всех состояниях кнопки.
static func tint(button: Button, color: Color) -> void:
	for key: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color",
			&"icon_hover_pressed_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override(&"icon_disabled_color", Color(color, 0.4))


## Знак роли дома по её имени (данные: «Прямой урон», «Контроль толпы», «Финишер»…).
static func role(role_text: String) -> Texture2D:
	if role_text.contains("Финишер"):
		return named("role_finisher")
	if role_text.contains("Контроль"):
		return named("role_control")
	if role_text.contains("област") or role_text.contains("групп") or role_text.contains("зоны") \
			or role_text.contains("Залп"):
		return named("role_area")
	if role_text.contains("Прямой") or role_text.contains("разряд"):
		return named("role_single")
	return named("role_status")


## Знак умения героя: удар Ильи, свист Соловья, варево Яги.
static func skill(kind: RitualHeroData.Skill) -> Texture2D:
	match kind:
		RitualHeroData.Skill.WHISTLE:
			return named("skill_solovei")
		RitualHeroData.Skill.BREW:
			return named("skill_yaga")
	return named("skill_ilya")

extends Control
## Изолированная художественная проба 2.5D, без экономики и правил симуляции.

const BACKGROUND: Texture2D = preload("res://assets/visual_slice/courtyard.png")
const ICE: Texture2D = preload("res://assets/visual_slice/ice.png")
const CANNON: Texture2D = preload("res://assets/visual_slice/cannon.png")
const SOLDIER: Texture2D = preload("res://assets/visual_slice/soldier.png")
const GOLD: Color = Color("b89760")
const INK: Color = Color("09121b")
const TEXT: Color = Color("eee3cb")
const MUTED: Color = Color("a7b3bf")
const ARENA: Rect2 = Rect2(438, 88, 1140, 760)
const ICE_FOOT: Vector2 = Vector2(1172, 407)
const CANNON_FOOT: Vector2 = Vector2(880, 614)
const ROUTE: Array[Vector2] = [
	Vector2(526, 366), Vector2(1009, 366), Vector2(1009, 528), Vector2(1500, 528)]

var _canvas: Control
var _clock: float = 0.0
var _travel: float = 0.0
var _is_running: bool = true
var _selected: int = 0
var _title: Label
var _description: Label
var _pause: Button
var _cards: Array[Button] = []


func _ready() -> void:
	_canvas = Control.new()
	_canvas.size = Vector2(1600, 900)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_canvas)
	_build_interface()
	resized.connect(_fit_canvas)
	_fit_canvas()
	_select_tower(0)


func _process(delta: float) -> void:
	_clock += delta
	if _is_running:
		_travel = fmod(_travel + delta * 55.0, 1136.0)
	_canvas.queue_redraw()


func _fit_canvas() -> void:
	var factor: float = minf(size.x / 1600.0, size.y / 900.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1600, 900) * factor) * 0.5


func _draw_canvas() -> void:
	_canvas.draw_rect(Rect2(0, 0, 1600, 900), Color("060c13"))
	_canvas.draw_texture_rect(BACKGROUND, ARENA, false)
	_draw_panel(Rect2(24, 88, 414, 760))
	_draw_panel(Rect2(460, 24, 1096, 54))
	_draw_panel(Rect2(486, 796, 1046, 56))
	_canvas.draw_line(Vector2(46, 177), Vector2(414, 177), GOLD.darkened(0.45))
	_canvas.draw_line(Vector2(46, 430), Vector2(414, 430), GOLD.darkened(0.45))
	_canvas.draw_line(Vector2(46, 643), Vector2(414, 643), GOLD.darkened(0.45))
	var foot: Vector2 = _soldier_point()
	# Сортировка по опорной точке сохраняет перекрытие бойца и построек.
	_draw_tower(ICE, ICE_FOOT, Vector2(172, 218), 0)
	if foot.y < CANNON_FOOT.y:
		_draw_soldier(foot)
	_draw_tower(CANNON, CANNON_FOOT, Vector2(187, 196), 1)
	if foot.y >= CANNON_FOOT.y:
		_draw_soldier(foot)
	_draw_embers()


func _draw_panel(rect: Rect2) -> void:
	_canvas.draw_style_box(_panel_style(INK, GOLD.darkened(0.25)), rect)


func _draw_tower(texture: Texture2D, foot: Vector2, dimensions: Vector2, index: int) -> void:
	_draw_ellipse(foot + Vector2(13, 0), Vector2(66, 19), Color(0, 0, 0, 0.5))
	if index == 0:
		for ring: int in range(8, 0, -1):
			_draw_ellipse(foot, Vector2(40 + ring * 6, 12 + ring * 2),
					Color(0.12, 0.6, 1.0, 0.018))
	if _selected == index:
		_draw_ellipse(foot, Vector2(72, 23), Color(0.35, 0.72, 0.9, 0.13))
		_canvas.draw_set_transform(foot, 0, Vector2(1, 0.33))
		_canvas.draw_arc(Vector2.ZERO, 72, 0, TAU, 64, Color("b9cdd5"), 2.0, true)
		_canvas.draw_set_transform(Vector2.ZERO)
	_canvas.draw_texture_rect(texture, Rect2(foot - Vector2(dimensions.x * 0.5,
			dimensions.y * 0.94), dimensions), false)


func _draw_soldier(foot: Vector2) -> void:
	_draw_ellipse(foot + Vector2(5, 1), Vector2(20, 7), Color(0, 0, 0, 0.45))
	var bob: float = sin(_travel * 0.15) * 1.5 if _is_running else 0.0
	_canvas.draw_texture_rect(SOLDIER,
			Rect2(foot - Vector2(30, 78 + bob), Vector2(60, 84)), false)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	_canvas.draw_set_transform(center, 0, radius)
	_canvas.draw_circle(Vector2.ZERO, 1.0, color)
	_canvas.draw_set_transform(Vector2.ZERO)


func _draw_embers() -> void:
	for index: int in 18:
		var phase: float = fmod(_clock * 0.2 + index * 0.137, 1.0)
		var origin: Vector2 = Vector2(572, 683) if index % 2 == 0 else Vector2(1435, 683)
		var point: Vector2 = origin + Vector2(sin(index * 2.1 + phase * 5.0) * 17,
				-phase * 70)
		_canvas.draw_circle(point, 1.2, Color(1, 0.62, 0.2, (1.0 - phase) * 0.7))


func _soldier_point() -> Vector2:
	var remaining: float = _travel
	for index: int in ROUTE.size() - 1:
		var distance: float = ROUTE[index].distance_to(ROUTE[index + 1])
		if remaining <= distance:
			return ROUTE[index].lerp(ROUTE[index + 1], remaining / distance)
		remaining -= distance
	return ROUTE[0]


func _build_interface() -> void:
	_label("З А С Т А В А", Rect2(28, 25, 390, 44), 29, TEXT)
	_label("СУМЕРЕЧНЫЙ ДВОР", Rect2(484, 37, 370, 30), 18, TEXT)
	_label("Проба стиля  /  2.5D", Rect2(1230, 37, 300, 30), 16, MUTED)
	_label("Лавка", Rect2(46, 108, 330, 38), 30, TEXT)
	_label("Две постройки · один отряд", Rect2(47, 148, 350, 25), 16, MUTED)
	_create_card(ICE, "Ледяная башня", "Выбрать", Rect2(46, 198, 174, 210), 0)
	_create_card(CANNON, "Орудие", "Выбрать", Rect2(240, 198, 174, 210), 1)
	_title = _label("", Rect2(47, 454, 360, 38), 25, TEXT)
	_description = _label("", Rect2(47, 505, 350, 108), 18, MUTED)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("ДРУЖИНА", Rect2(47, 662, 350, 30), 17, GOLD)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = SOLDIER
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(48, 701)
	portrait.size = Vector2(76, 111)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(portrait)
	_label("Дружинник", Rect2(141, 713, 255, 30), 23, TEXT)
	_label("Один боец на дороге", Rect2(141, 752, 255, 25), 16, MUTED)
	_label("Выбери башню в лавке или на поле", Rect2(507, 814, 670, 28), 17, TEXT)
	_pause = _button("Пауза", Rect2(1276, 805, 112, 38))
	_pause.pressed.connect(_toggle_pause)
	var back: Button = _button("В меню", Rect2(1400, 805, 112, 38))
	back.pressed.connect(_back_to_menu)
	for index: int in 2:
		var hit: Button = Button.new()
		hit.flat = true
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.position = (ICE_FOOT if index == 0 else CANNON_FOOT) - Vector2(77, 180)
		hit.size = Vector2(154, 193)
		hit.pressed.connect(_select_tower.bind(index))
		_canvas.add_child(hit)


func _create_card(texture: Texture2D, title: String, caption: String,
		rect: Rect2, index: int) -> void:
	var card: Button = _button("", rect)
	card.pressed.connect(_select_tower.bind(index))
	_cards.append(card)
	var picture: TextureRect = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = texture
	picture.position = Vector2(12, 10)
	picture.size = Vector2(rect.size.x - 24, 145)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(picture)
	_label(title, Rect2(rect.position + Vector2(12, 158), Vector2(160, 25)), 17, TEXT)
	_label(caption, Rect2(rect.position + Vector2(12, 184), Vector2(150, 22)), 14, GOLD)


func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
	return label


func _button(text: String, rect: Rect2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(INK, GOLD.darkened(0.4)))
	button.add_theme_stylebox_override("hover", _panel_style(Color("182936"), GOLD))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("24333a"), TEXT))
	_canvas.add_child(button)
	return button


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	return style


func _select_tower(index: int) -> void:
	_selected = index
	_title.text = "ЛЕДЯНАЯ БАШНЯ" if index == 0 else "ОРУДИЕ"
	_description.text = ("Холодный кристалл, тёмный камень и железо.\n\nВыбрана на поле."
			if index == 0 else "Тяжёлый ствол, потёртая бронза и дерево.\n\nВыбрано на поле.")
	for card_index: int in _cards.size():
		_cards[card_index].add_theme_stylebox_override("normal",
				_panel_style(INK, GOLD if index == card_index else GOLD.darkened(0.6)))


func _toggle_pause() -> void:
	_is_running = not _is_running
	_pause.text = "Пауза" if _is_running else "Продолжить"


func _back_to_menu() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

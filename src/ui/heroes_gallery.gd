extends Control
## Галерея героев из главного меню: все герои из конфига матча — портрет, HP, пассивка, навык.
## Собирается кодом из данных (новый герой в конфиге сам появится здесь).

const CONFIG_PATH: String = "res://data/game_config.tres"
const PORTRAIT_SIZE: float = 96.0
const CARD_WIDTH: float = 300.0
const COLOR_MUTED: Color = Color(0.73, 0.67, 0.56)
const COLOR_HP: Color = Color(0.92, 0.5, 0.42)
const COLOR_SKILL: Color = Color(0.91, 0.65, 0.29)
const COLOR_TEXT: Color = Color(0.94, 0.89, 0.81)

var _grid: GridContainer


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = load("res://data/ui/ui_theme.tres") as Theme
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.08, 0.063, 0.05)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title: Label = _make_label("Герои", 36, COLOR_SKILL)
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	for hero: HeroData in config.heroes:
		_grid.add_child(_make_card(hero))
	var back: Button = Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_on_back_pressed)
	UiFx.add_press_feedback(back)
	box.add_child(back)
	_update_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		ScreenFit.apply(get_window())
		_update_columns()


func _update_columns() -> void:
	if _grid != null:
		_grid.columns = maxi(1, int(size.x / (CARD_WIDTH + 12.0)))


func _make_card(hero: HeroData) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = HeroPortraits.get_portrait(hero)
	portrait.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_make_label(hero.display_name, 22, COLOR_TEXT))
	text.add_child(_make_label("♥ %d HP · %s" % [hero.hp, hero.style], 16, COLOR_HP))
	text.add_child(_make_label(hero.description, 15, COLOR_TEXT))
	if hero.skill != null:
		var skill: HeroSkillData = hero.skill
		text.add_child(_make_label("Навык «%s» · %d зол. · %s" % [skill.display_name, skill.cost,
				skill.get_timing_text()], 15, COLOR_SKILL))
		text.add_child(_make_label(skill.description, 14, COLOR_MUTED))
	return card


func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_back_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

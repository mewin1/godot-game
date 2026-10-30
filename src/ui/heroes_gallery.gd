extends Control
## Справочник из главного меню: герои (портрет, HP, пассивка, навык), постройки и мобы.
## Собирается кодом из данных (новый герой, постройка или моб сам появится здесь).

const CONFIG_PATH: String = "res://data/game_config.tres"
const PORTRAIT_SIZE: float = 96.0
const CARD_WIDTH: float = 300.0
const COLOR_MUTED: Color = Color(0.73, 0.67, 0.56)
const COLOR_HP: Color = Color(0.92, 0.5, 0.42)
const COLOR_SKILL: Color = Color(0.91, 0.65, 0.29)
const COLOR_TEXT: Color = Color(0.94, 0.89, 0.81)

const MOB_IDS: Array[StringName] = [&"basic", &"send_unit", &"fast", &"armored",
		&"healer", &"knight", &"stealth", &"boss", &"robber"]

var _grids: Array[GridContainer] = []


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
	var title: Label = _make_label("Справочник: герои, постройки, мобы", 32, COLOR_SKILL)
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var sections: VBoxContainer = VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	var heroes: GridContainer = _add_section(sections, "")
	for hero: HeroData in config.heroes:
		heroes.add_child(_make_card(hero))
	var towers: GridContainer = _add_section(sections, "Постройки")
	var catalog: VisualCatalog = VisualCatalog.get_default()
	for data: TowerData in config.towers:
		var visual: TowerVisual = catalog.get_tower(data.id)
		towers.add_child(_make_entry(visual.icon, data.display_name,
				"Тир %d · клеток %d" % [data.tier, data.shape.size()], data.description))
	var mobs: GridContainer = _add_section(sections, "Мобы")
	for mob_id: StringName in MOB_IDS:
		var mob: MobData = load("res://data/mobs/%s.tres" % mob_id) as MobData
		mobs.add_child(_make_entry(catalog.get_mob(mob_id).texture, mob.display_name,
				"HP %d" % mob.hp, mob.description))
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
	for grid: GridContainer in _grids:
		grid.columns = maxi(1, int(size.x / (CARD_WIDTH + 12.0)))


## Раздел справочника: заголовок (может быть пустым) и сетка карточек.
func _add_section(parent: Container, caption: String) -> GridContainer:
	if caption != "":
		var label: Label = _make_label(caption, 30, COLOR_SKILL)
		label.theme_type_variation = &"HeaderLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(label)
	var grid: GridContainer = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	_grids.append(grid)
	return grid


## Карточка постройки или моба: картинка, имя, короткая строка, описание.
func _make_entry(icon: Texture2D, title: String, info: String, details: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE * 0.7
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(picture)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_make_label(title, 20, COLOR_TEXT))
	text.add_child(_make_label(info, 15, COLOR_HP))
	text.add_child(_make_label(details, 14, COLOR_MUTED))
	return card


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
	text.add_child(_make_label(hero.get_passive_text(), 15, COLOR_TEXT))
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

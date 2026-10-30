class_name HeroSelectPanel
extends Control
## Выбор героя перед матчем: три карточки (портрет, имя, HP, пассивка, навык) и таймер.
## Только показывает предложения; выбор отдаёт наверх сигналом.

signal hero_chosen(offer_index: int)

const PORTRAIT_SIZE: float = 132.0
const CARD_MIN_WIDTH: float = 210.0
const COLOR_DIM: Color = Color(0, 0, 0, 0.72)
const COLOR_MUTED: Color = Color(0.73, 0.67, 0.56)
const COLOR_HP: Color = Color(0.92, 0.5, 0.42)
const COLOR_SKILL: Color = Color(0.91, 0.65, 0.29)

var _title: Label
var _draft_label: Label
var _timer_label: Label
var _cards_box: BoxContainer
var _cards: Array[PanelContainer] = []
var _is_chosen: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_title = _make_label("Выберите героя", 34)
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_draft_label = _make_label("", 18, COLOR_SKILL)
	_draft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_draft_label)
	_timer_label = _make_label("", 18, COLOR_MUTED)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_label)
	_cards_box = BoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 12)
	box.add_child(_cards_box)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _cards_box != null:
		# Узкий высокий экран: карточки столбиком, иначе в ряд.
		_cards_box.vertical = size.x < CARD_MIN_WIDTH * 3.2 and size.y > size.x


## Показывает предложенных героев (один раз в начале матча).
func show_offers(offers: Array[HeroData], gods: Array[StringName] = []) -> void:
	var names: PackedStringArray = []
	for god: StringName in gods:
		names.append(IdolSlot.god_name(god))
	_draft_label.text = "Боги матча: " + " · ".join(names) if not gods.is_empty() else ""
	for card: PanelContainer in _cards:
		card.queue_free()
	_cards.clear()
	_is_chosen = false
	for i: int in offers.size():
		var card: PanelContainer = _make_card(offers[i], i)
		_cards_box.add_child(card)
		_cards.append(card)
		UiFx.pop_in(card, 0.08 * i)


func set_seconds_left(seconds: int) -> void:
	if _is_chosen:
		_timer_label.text = "Ждём остальных…"
	else:
		_timer_label.text = "Осталось %d с — потом возьмём первого" % seconds


func _make_card(hero: HeroData, offer_index: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = HeroPortraits.get_portrait(hero)
	portrait.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)
	var title: Label = _make_label(hero.display_name, 24)
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var epithet: Label = _make_label(hero.epithet, 14, COLOR_MUTED)
	epithet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(epithet)
	var hp: Label = _make_label("♥ %d HP · %s" % [hero.hp, hero.style], 17, COLOR_HP)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hp)
	box.add_child(_make_label(hero.get_passive_text(), 16))
	if hero.affinity_gift != null:
		box.add_child(_make_label("Дар %s: %s" % [IdolSlot.god_name(hero.affinity_god),
				hero.affinity_gift.display_name], 15, COLOR_SKILL))
	if hero.skill != null:
		var skill: HeroSkillData = hero.skill
		box.add_child(_make_label("Навык «%s» · %d зол. · %s" % [skill.display_name, skill.cost,
				skill.get_timing_text()], 16, COLOR_SKILL))
		box.add_child(_make_label(skill.description, 15))
	var button: Button = Button.new()
	button.text = "Выбрать"
	button.theme_type_variation = &"AccentButton"
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_on_choose_pressed.bind(offer_index))
	UiFx.add_press_feedback(button)
	box.add_child(button)
	return card


func _make_label(text: String, font_size: int, color: Color = Color(0.94, 0.89, 0.81)) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_choose_pressed(offer_index: int) -> void:
	if _is_chosen:
		return
	_is_chosen = true
	for i: int in _cards.size():
		_cards[i].theme_type_variation = &"CardPanelActive" if i == offer_index else &"CardPanel"
		_cards[i].modulate = Color.WHITE if i == offer_index else Color(1, 1, 1, 0.45)
	hero_chosen.emit(offer_index)

class_name RitualIdolPopup
extends PanelContainer
## Окно идола на площади (docs/37 IDL-2): у пустого идола — выбор бога, у посвящённого —
## заговоры этого бога с текущим и следующим бонусом и ценой. Покупка — команда RITE
## с номером идола; первое приобретение посвящает пустой идол навсегда.

signal rite_requested(rite_index: int, idol_index: int)
signal closed()

const WIDTH: float = 340.0
const GOLD_ICON: Texture2D = preload("res://assets/ui/icon_gold.svg")

var idol_index: int = -1
## Бог, выбранный в окне пустого идола (до первой покупки ничего не посвящено).
var _picked_god: StringName = &""
var _title: Label
var _body: VBoxContainer
var _signature: String = ""


func _init() -> void:
	add_theme_stylebox_override("panel", DuskTheme.panel(Color(0.04, 0.07, 0.11, 0.96), DuskTheme.GOLD, 10))
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 5
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	# Заголовок окна идола — Kurale крупнее пунктов (critique_3 п. 70, 79).
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("e9cea2"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close: Button = Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Закрыть (Esc, ПКМ)"
	close.pressed.connect(close_popup)
	head.add_child(close)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	box.add_child(_body)
	visible = false


func open(index: int) -> void:
	idol_index = index
	_picked_god = &""
	_signature = ""
	visible = true


func close_popup() -> void:
	if not visible:
		return
	visible = false
	idol_index = -1
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		close_popup()
		accept_event()


## Содержимое пересобирается, только когда меняется то, что видно (цены, золото, посвящение).
func refresh(trial: RitualTrial) -> void:
	if not visible or idol_index < 0 or idol_index >= trial.field.idols.size():
		return
	var idol: IdolState = trial.field.idols[idol_index]
	var god: StringName = idol.god if idol.god != &"" else _picked_god
	var parts: PackedStringArray = [str(idol_index), String(god), str(trial.gold), str(int(trial.phase))]
	for index: int in trial.settings.rites.size():
		parts.append(str(trial.rite_count(index)))
	var signature: String = ",".join(parts)
	if signature == _signature:
		return
	_signature = signature
	for child: Node in _body.get_children():
		# Сразу из дерева: иначе старые строки до конца кадра растягивают окно.
		_body.remove_child(child)
		child.queue_free()
	if god == &"":
		_title.text = "Идол %d · пустой" % (idol_index + 1)
		_fill_gods(trial)
	else:
		_title.text = "Идол %d · %s" % [idol_index + 1, RitualScoutQueue.element_name(god)]
		_fill_rites(trial, god, idol.god == &"")
	size = Vector2.ZERO
	reset_size()


func _fill_gods(trial: RitualTrial) -> void:
	_note("Выберите стихию — навсегда.", "Посвящение навсегда, с первым заговором; бог — в подсказке стихии.")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	var seen: Dictionary[StringName, bool] = {}
	for rite: RiteData in trial.settings.rites:
		if seen.has(rite.god):
			continue
		seen[rite.god] = true
		var button: Button = Button.new()
		# Семь пунктов одного вида (critique_4 п. 45): знак стихии её цветом и имя стихии; бог — в подсказке.
		button.text = RitualScoutQueue.element_name(rite.god)
		button.icon = RitualIcons.god(rite.god)
		RitualIcons.tint(button, GodSymbols.get_color(rite.god))
		button.add_theme_constant_override("icon_max_width", 24)
		button.custom_minimum_size = Vector2(160, 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.name = "IdolGod_%s" % rite.god
		var elsewhere: IdolState = trial.field.get_idol(rite.god)
		button.disabled = elsewhere != null
		button.tooltip_text = "Этот бог уже живёт в другом идоле" if elsewhere != null \
			else "%s. Заговоры стихии; скидка на её постройки растёт с каждым заговором" % GodSymbols.get_power_name(rite.god)
		button.pressed.connect(_pick_god.bind(rite.god))
		grid.add_child(button)


func _pick_god(god: StringName) -> void:
	_picked_god = god
	_signature = ""


func _fill_rites(trial: RitualTrial, god: StringName, preview: bool) -> void:
	if preview:
		var back: Button = Button.new()
		back.text = "← другой бог"
		back.flat = true
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(_pick_god.bind(&""))
		_body.add_child(back)
		_note("Первый заговор посвятит идол навсегда.")
	for index: int in trial.settings.rites.size():
		var rite: RiteData = trial.settings.rites[index]
		if rite.god != god:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_body.add_child(row)
		# Плейтест 19 ноября («глаза разбегаются»): имя и одна строка «сейчас → со следующим»;
		# описание, предел и скидка — в подсказке.
		var text: VBoxContainer = VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.tooltip_text = RitualShopPanel.rite_tooltip(trial, index)
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title: Label = Label.new()
		title.text = rite.display_name
		title.add_theme_font_size_override("font_size", 18)
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		text.add_child(title)
		var effect: Label = Label.new()
		effect.text = _effect_line(trial, index)
		effect.add_theme_font_size_override("font_size", 15)
		effect.add_theme_color_override("font_color", Color("b9c4c9"))
		effect.mouse_filter = Control.MOUSE_FILTER_PASS
		text.add_child(effect)
		var buy: Button = Button.new()
		var cost: int = trial.rite_cost(index)
		buy.text = str(cost)
		buy.icon = GOLD_ICON
		buy.add_theme_constant_override("icon_max_width", 18)
		buy.name = "IdolRite_%s" % rite.id
		buy.custom_minimum_size = Vector2(76, 34)
		buy.focus_mode = Control.FOCUS_NONE
		var maxed: bool = trial.settings.rite_purchase_limit and trial.rite_count(index) >= rite.max_purchases
		buy.disabled = maxed or trial.gold < cost or trial.phase != RitualTrial.Phase.RUNNING
		buy.tooltip_text = "Заговор уже на пределе" if maxed else "Не хватает золота" if trial.gold < cost \
				else "Купить заговор за %d" % cost
		buy.pressed.connect(func() -> void: rite_requested.emit(index, idol_index))
		row.add_child(buy)
	_fill_milestones(trial, god)
	var discount: int = trial.discount_bp(god)
	if discount > 0:
		_note("Скидка стихии: −%d%%" % (discount / 100),
				"Скидка на постройки и улучшения стихии «%s»" % RitualScoutQueue.element_name(god))


## Вехи бога (docs/37 IDL-4): пройденные — золотом, следующая — сколько заговоров осталось.
func _fill_milestones(trial: RitualTrial, god: StringName) -> void:
	var milestones: Array[RitualIdolMilestone] = trial.settings.milestones_for(god)
	if milestones.is_empty():
		return
	var idol: IdolState = trial.field.idols[idol_index]
	var count: int = trial.idol_rites(idol) if idol.god == god else 0
	# Вехи одной строкой (плейтест 19 ноября): «Вехи ✓5 ○10 ○15», что дают — в подсказке.
	var marks: PackedStringArray = []
	var details: PackedStringArray = ["Вехи идола · заговоров куплено: %d" % count]
	for milestone: RitualIdolMilestone in milestones:
		var reached: bool = count >= milestone.rites
		marks.append("%s%d" % ["✓" if reached else "○", milestone.rites])
		details.append("%s %d · %s — %s%s" % ["✓" if reached else "○", milestone.rites, milestone.title,
			milestone.description, "" if reached else " (ещё %d)" % (milestone.rites - count)])
	var line: Label = Label.new()
	line.text = "Вехи  " + "  ".join(marks)
	line.tooltip_text = "\n".join(details)
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.add_theme_font_size_override("font_size", 18)
	line.add_theme_color_override("font_color", Color("e9cea2"))
	_body.add_child(line)


## «+10% → +12%»: сейчас и со следующим заговором (без предела — +N% за каждый).
static func _effect_line(trial: RitualTrial, index: int) -> String:
	var rite: RiteData = trial.settings.rites[index]
	var count: int = trial.rite_count(index)
	var curve: RitualRiteCurve = trial.settings.rite_curve(rite.id)
	if curve == null or curve.cap <= 0:
		return "+%d%% → +%d%% урона" % [rite.value * count, rite.value * (count + 1)]
	return "%s → %s" % [RitualShopPanel._amount(rite.effect, RitualRiteCurve.decay(curve.cap, curve.step_bp, count)),
		RitualShopPanel._amount(rite.effect, RitualRiteCurve.decay(curve.cap, curve.step_bp, count + 1))]


func _note(text: String, tip: String = "") -> void:
	var label: Label = Label.new()
	label.text = text
	label.tooltip_text = tip
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 24.0
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("b9c4c9"))
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(label)

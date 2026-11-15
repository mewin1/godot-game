class_name RitualIdolPopup
extends PanelContainer
## Окно идола на площади (docs/37 IDL-2): у пустого идола — выбор бога, у посвящённого —
## заговоры этого бога с текущим и следующим бонусом и ценой. Покупка — команда RITE
## с номером идола; первое приобретение посвящает пустой идол навсегда.

signal rite_requested(rite_index: int, idol_index: int)
signal closed()

const WIDTH: float = 340.0

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
	_title.add_theme_font_size_override("font_size", 18)
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
		_title.text = "Идол %d · %s" % [idol_index + 1, GodSymbols.get_power_name(god)]
		_fill_rites(trial, god, idol.god == &"")
	size = Vector2.ZERO
	reset_size()


func _fill_gods(trial: RitualTrial) -> void:
	_note("Кому посвятить идол? Посвящение — навсегда, с первым заговором.")
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
		button.text = GodSymbols.get_power_name(rite.god)
		button.icon = GodSymbols.get_icon(rite.god)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(160, 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.name = "IdolGod_%s" % rite.god
		var elsewhere: IdolState = trial.field.get_idol(rite.god)
		button.disabled = elsewhere != null
		button.tooltip_text = "Этот бог уже живёт в другом идоле" if elsewhere != null \
			else "Заговоры %s; скидка на его постройки растёт с каждым заговором" % GodSymbols.get_power_name(rite.god)
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
		_note("Первый заговор посвятит этот идол %s навсегда." % GodSymbols.get_power_name(god))
	for index: int in trial.settings.rites.size():
		var rite: RiteData = trial.settings.rites[index]
		if rite.god != god:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_body.add_child(row)
		var text: Label = Label.new()
		var lines: PackedStringArray = RitualShopPanel.rite_tooltip(trial, index).split("\n")
		# Имя и строка «куплено n: сейчас … со следующим …» (вторая строка подсказки — описание).
		text.text = "%s\n%s" % [lines[0], lines[2] if lines.size() > 2 else rite.description]
		text.tooltip_text = "\n".join(lines)
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 18)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Ширина обязательна: перенос по словам без неё считает высоту по одной букве в строке.
		text.custom_minimum_size.x = WIDTH - 140.0
		row.add_child(text)
		var buy: Button = Button.new()
		var cost: int = trial.rite_cost(index)
		buy.text = "Купить · %d" % cost
		buy.name = "IdolRite_%s" % rite.id
		buy.custom_minimum_size = Vector2(104, 34)
		buy.focus_mode = Control.FOCUS_NONE
		var maxed: bool = trial.settings.rite_purchase_limit and trial.rite_count(index) >= rite.max_purchases
		buy.disabled = maxed or trial.gold < cost or trial.phase != RitualTrial.Phase.RUNNING
		buy.tooltip_text = "Заговор уже на пределе" if maxed else "Не хватает золота" if trial.gold < cost else ""
		buy.pressed.connect(func() -> void: rite_requested.emit(index, idol_index))
		row.add_child(buy)
	_fill_milestones(trial, god)
	var discount: int = trial.discount_bp(god)
	if discount > 0:
		_note("Скидка на постройки и улучшения %s: −%d%%" % [GodSymbols.get_power_name(god), discount / 100])


## Вехи бога (docs/37 IDL-4): пройденные — золотом, следующая — сколько заговоров осталось.
func _fill_milestones(trial: RitualTrial, god: StringName) -> void:
	var milestones: Array[RitualIdolMilestone] = trial.settings.milestones_for(god)
	if milestones.is_empty():
		return
	var idol: IdolState = trial.field.idols[idol_index]
	var count: int = trial.idol_rites(idol) if idol.god == god else 0
	var title: Label = Label.new()
	title.text = "Вехи идола · заговоров %d" % count
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("e9cea2"))
	_body.add_child(title)
	for milestone: RitualIdolMilestone in milestones:
		var line: Label = Label.new()
		var reached: bool = count >= milestone.rites
		line.text = "%s %d · %s — %s%s" % ["✓" if reached else "○", milestone.rites, milestone.title,
			milestone.description, "" if reached else " (ещё %d)" % (milestone.rites - count)]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = WIDTH - 24.0
		line.add_theme_font_size_override("font_size", 18)
		line.add_theme_color_override("font_color", Color("f0c869") if reached else Color("b9c4c9"))
		_body.add_child(line)


func _note(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 24.0
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("b9c4c9"))
	_body.add_child(label)

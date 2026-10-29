class_name MatchScreen
extends Control
## Экран матча без камеры: сверху строка состояния, ниже две половины.
## Подготовка: меню (магазин) + своё поле. Волна: поле соперника + своё поле.
## Широкий экран — половины слева/справа, высокий (телефон) — сверху/снизу (автоматически).
## Крутит симуляцию с фиксированным тиком и передаёт в неё команды игрока.

const CONFIG_PATH: String = "res://data/game_config.tres"
const HUMAN_INDEX: int = 0
const BASE_FONT_SIZE: int = 20
const HUD_FONT_SIZE: int = 22
const TOAST_SECONDS: float = 2.0
## Не больше стольких тиков за кадр — чтобы игра не «догоняла» рывком после подвисания.
const MAX_TICKS_PER_FRAME: int = 5
const COLOR_BACKGROUND: Color = Color(0.06, 0.07, 0.09)

@export var player_count: int = 2

var _sim: MatchSim
var _accumulator: float = 0.0
var _selected_tower_id: int = 0
var _toast_time_left: float = 0.0

var _hud_label: Label
var _halves: BoxContainer
var _menu_slot: Control
var _shop_panel: ShopPanel
var _opponent_view: FieldView
var _my_view: FieldView
var _toast_label: Label
var _game_over_panel: PanelContainer
var _game_over_label: Label


func _ready() -> void:
	_build_ui()
	_update_split_direction()
	_start_match()


func _process(delta: float) -> void:
	_step_simulation(delta)
	_refresh_views()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _halves != null:
		_update_split_direction()


## Высокий экран (телефон) — половины сверху/снизу, широкий (ПК) — слева/справа.
func _update_split_direction() -> void:
	_halves.vertical = size.y > size.x


#region Построение интерфейса

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	var background: ColorRect = ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_box)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	_hud_label.custom_minimum_size = Vector2(0, 40)
	_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root_box.add_child(_hud_label)
	_halves = BoxContainer.new()
	_halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_halves)
	_build_halves()
	_build_toast()
	_build_game_over()


## Крупные контрастные кнопки: на телефоне по ним попадают пальцем.
func _make_theme() -> Theme:
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font_size = BASE_FONT_SIZE
	ui_theme.set_stylebox("normal", "Button", _make_button_style(Color(0.24, 0.27, 0.34)))
	ui_theme.set_stylebox("hover", "Button", _make_button_style(Color(0.3, 0.34, 0.43)))
	ui_theme.set_stylebox("pressed", "Button", _make_button_style(Color(0.18, 0.2, 0.26)))
	ui_theme.set_stylebox("disabled", "Button", _make_button_style(Color(0.14, 0.15, 0.18)))
	ui_theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.11, 0.14)
	panel.set_content_margin_all(10)
	ui_theme.set_stylebox("panel", "PanelContainer", panel)
	return ui_theme


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	return style


func _build_halves() -> void:
	_menu_slot = Control.new()
	_make_half(_menu_slot)
	_shop_panel = ShopPanel.new()
	_shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_panel.command_requested.connect(_on_command_requested)
	_menu_slot.add_child(_shop_panel)
	_opponent_view = FieldView.new()
	_opponent_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_slot.add_child(_opponent_view)
	_my_view = FieldView.new()
	_make_half(_my_view)
	_my_view.command_requested.connect(_on_command_requested)
	_my_view.tower_tapped.connect(_on_my_view_tower_tapped)


func _make_half(half: Control) -> void:
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.clip_contents = true
	_halves.add_child(half)


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.position.y -= 60
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)


func _build_game_over() -> void:
	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.visible = false
	add_child(_game_over_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_game_over_panel.add_child(box)
	_game_over_label = Label.new()
	_game_over_label.add_theme_font_size_override("font_size", 40)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_label)
	var restart: Button = Button.new()
	restart.text = "Новый матч"
	restart.custom_minimum_size = Vector2(320, 72)
	restart.add_theme_font_size_override("font_size", 28)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)

#endregion


func _start_match() -> void:
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	# Сид матча выбирает отображение: внутри симуляции случайность только от этого сида.
	_sim = MatchSim.new(config, randi(), player_count, 1)
	_sim.command_failed.connect(_on_sim_command_failed)
	_sim.match_finished.connect(_on_sim_match_finished)
	_sim.phase_changed.connect(_on_sim_phase_changed)
	_sim.start()
	_shop_panel.setup(_sim, _human())


func _step_simulation(delta: float) -> void:
	var tick_seconds: float = 1.0 / _sim.config.ticks_per_second
	_accumulator += delta
	var ticks: int = 0
	while _accumulator >= tick_seconds and ticks < MAX_TICKS_PER_FRAME:
		_sim.tick()
		_accumulator -= tick_seconds
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0
	var alpha: float = clampf(_accumulator / tick_seconds, 0.0, 1.0)
	_my_view.interpolation = alpha
	_opponent_view.interpolation = alpha


func _refresh_views() -> void:
	var me: PlayerState = _human()
	var is_prep: bool = _sim.phase == MatchSim.Phase.PREP
	if me.field.get_tower(_selected_tower_id) == null or not is_prep:
		_selected_tower_id = 0
	_my_view.show_field(me.field, _sim.config, "Ваше поле")
	_my_view.hero_hp = me.hero_hp
	_my_view.can_edit = is_prep and me.is_alive
	_my_view.selected_tower_id = _selected_tower_id
	_shop_panel.visible = is_prep and me.is_alive
	_shop_panel.refresh(me.field.get_tower(_selected_tower_id))
	var opponent: PlayerState = _opponent()
	_opponent_view.visible = not _shop_panel.visible and opponent != null
	if opponent != null:
		_opponent_view.show_field(opponent.field, _sim.config, "Поле соперника: %s" % opponent.display_name)
		_opponent_view.hero_hp = opponent.hero_hp
	_hud_label.text = _hud_text()
	_update_toast()


func _hud_text() -> String:
	var me: PlayerState = _human()
	var seconds: int = ceili(float(_sim.get_phase_ticks_left()) / _sim.config.ticks_per_second)
	var phase_name: String = "Подготовка %d с" % seconds if _sim.phase == MatchSim.Phase.PREP \
			else "Волна"
	if _sim.phase == MatchSim.Phase.OVER:
		phase_name = "Матч окончен"
	var text: String = "  Раунд %d · %s   |   Вы: HP %d · золото %d (+%d за раунд)" % [
			_sim.round_number, phase_name, me.hero_hp, me.gold, me.income]
	var opponent: PlayerState = _opponent()
	if opponent != null:
		text += "   |   %s: HP %d" % [opponent.display_name, opponent.hero_hp]
	return text


func _update_toast() -> void:
	_toast_time_left = maxf(0.0, _toast_time_left - get_process_delta_time())
	_toast_label.modulate.a = clampf(_toast_time_left, 0.0, 1.0)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.reset_size()
	_toast_label.position.x = (size.x - _toast_label.size.x) / 2.0
	_toast_time_left = TOAST_SECONDS


func _human() -> PlayerState:
	return _sim.players[HUMAN_INDEX]


func _opponent() -> PlayerState:
	var index: int = _sim.opponent_of[HUMAN_INDEX]
	return _sim.players[index] if index != MatchSim.GHOST else null


func _on_command_requested(command: SimCommand) -> void:
	_sim.queue_command(HUMAN_INDEX, command)


func _on_my_view_tower_tapped(tower_id: int) -> void:
	_selected_tower_id = tower_id if tower_id != _selected_tower_id else 0


func _on_sim_command_failed(player_index: int, reason: String) -> void:
	if player_index == HUMAN_INDEX:
		_show_toast(reason)


func _on_sim_phase_changed(phase: MatchSim.Phase) -> void:
	if phase == MatchSim.Phase.WAVE:
		_show_toast("Волна!")


func _on_sim_match_finished() -> void:
	var me: PlayerState = _human()
	_game_over_label.text = "Победа!" if me.place == 1 else "Поражение · место %d" % me.place
	_game_over_panel.visible = true
	_game_over_panel.reset_size()
	_game_over_panel.position = (size - _game_over_panel.size) / 2.0


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

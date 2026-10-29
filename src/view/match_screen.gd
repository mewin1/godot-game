class_name MatchScreen
extends Control
## Экран матча без камеры: сверху панель (MatchHud), ниже две половины.
## Подготовка: меню (магазин) + своё поле. Волна: поле соперника + своё поле.
## Широкий экран — половины слева/справа, высокий (телефон) — сверху/снизу (автоматически).
## Крутит симуляцию с фиксированным тиком и передаёт в неё команды игрока.

const CONFIG_PATH: String = "res://data/game_config.tres"
const THEME_PATH: String = "res://data/ui/ui_theme.tres"
const VIGNETTE_SHADER: Shader = preload("res://assets/shaders/vignette.gdshader")
const END_PANEL_SCENE: PackedScene = preload("res://scenes/match_end_panel.tscn")
## Логи живых матчей (для разработки: папка проекта, в git не попадает).
const LIVE_LOG_DIR: String = "res://logs/live"
const HUMAN_INDEX: int = 0
const TOAST_SECONDS: float = 2.0
const TOAST_FONT_SIZE: int = 24
const HALF_FADE_SECONDS: float = 0.35
## Не больше стольких тиков за кадр — чтобы игра не «догоняла» рывком после подвисания.
const MAX_TICKS_PER_FRAME: int = 5
const COLOR_BACKGROUND: Color = Color(0.08, 0.06, 0.047)
const COLOR_TOAST: Color = Color(1.0, 0.8, 0.45)
const COLOR_SIEGE: Color = Color(1.0, 0.45, 0.35)
const SPEEDS: Array[int] = [1, 2]

## Игроков в лобби: вы + боты.
@export var player_count: int = 5
## Писать лог матча для анализа баланса.
@export var is_logging_enabled: bool = true

var _sim: MatchSim
var _logger: MatchLogger
var _accumulator: float = 0.0
var _selected_tower_id: int = 0
var _toast_time_left: float = 0.0
var _is_paused: bool = false
var _speed_index: int = 0
var _was_prep_shown: bool = true
var _banner: Control

var _hud: MatchHud
var _halves: BoxContainer
var _menu_slot: Control
var _shop_panel: ShopPanel
var _opponent_view: FieldView
var _my_view: FieldView
var _overlay: Control
var _toast_label: Label
var _end_layer: Control
var _end_panel: MatchEndPanel
var _sound_bank: SoundBank


func _ready() -> void:
	_build_ui()
	_update_split_direction()
	_start_match()


func _exit_tree() -> void:
	# Пауза и ускорение действуют через общий масштаб времени — вернуть его для других сцен.
	Engine.time_scale = 1.0
	if _logger != null:
		_logger.close()


func _process(delta: float) -> void:
	_step_simulation(delta)
	_refresh_views()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _halves != null:
		_update_split_direction()


## Высокий экран (телефон) — половины сверху/снизу, широкий (ПК) — слева/справа.
func _update_split_direction() -> void:
	if is_inside_tree():
		ScreenFit.apply(get_window())
	_halves.vertical = size.y > size.x


#region Построение интерфейса

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = load(THEME_PATH) as Theme
	var background: ColorRect = ColorRect.new()
	background.color = COLOR_BACKGROUND
	_add_full_rect(self, background)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 4)
	_add_full_rect(self, root_box)
	root_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud = MatchHud.new()
	_hud.pause_pressed.connect(_on_hud_pause_pressed)
	_hud.speed_pressed.connect(_on_hud_speed_pressed)
	_hud.sound_pressed.connect(_on_hud_sound_pressed)
	_hud.set_muted(SoundBank.is_muted())
	root_box.add_child(_hud)
	_halves = BoxContainer.new()
	_halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_halves)
	_build_halves()
	_add_vignette()
	_overlay = Control.new()
	_add_full_rect(self, _overlay)
	_build_toast()
	_build_end_layer()
	_sound_bank = SoundBank.new()
	add_child(_sound_bank)


func _add_full_rect(parent: Control, child: Control) -> void:
	child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(child)
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Мягкое затемнение краёв поверх всего — «нуар».
func _add_vignette() -> void:
	var vignette: ColorRect = ColorRect.new()
	var vignette_material: ShaderMaterial = ShaderMaterial.new()
	vignette_material.shader = VIGNETTE_SHADER
	vignette_material.set_shader_parameter("strength", 0.45)
	vignette.material = vignette_material
	_add_full_rect(self, vignette)


func _build_halves() -> void:
	_menu_slot = Control.new()
	_make_half(_menu_slot)
	_shop_panel = ShopPanel.new()
	_shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_panel.command_requested.connect(_on_command_requested)
	_menu_slot.add_child(_shop_panel)
	_opponent_view = FieldView.new()
	_opponent_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opponent_view.sound_requested.connect(_on_view_sound_requested)
	_menu_slot.add_child(_opponent_view)
	_my_view = FieldView.new()
	_my_view.is_own_field = true
	_make_half(_my_view)
	_my_view.command_requested.connect(_on_command_requested)
	_my_view.tower_tapped.connect(_on_my_view_tower_tapped)
	_my_view.sound_requested.connect(_on_view_sound_requested)


func _make_half(half: Control) -> void:
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.clip_contents = true
	_halves.add_child(half)


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast_label.add_theme_color_override("font_color", COLOR_TOAST)
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_toast_label)


func _build_end_layer() -> void:
	_end_layer = Control.new()
	_end_layer.visible = false
	_add_full_rect(self, _end_layer)
	_end_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_add_full_rect(_end_layer, dim)
	var center: CenterContainer = CenterContainer.new()
	_add_full_rect(_end_layer, center)
	_end_panel = END_PANEL_SCENE.instantiate() as MatchEndPanel
	_end_panel.again_pressed.connect(_on_end_panel_again_pressed)
	_end_panel.menu_pressed.connect(_on_end_panel_menu_pressed)
	center.add_child(_end_panel)

#endregion


func _start_match() -> void:
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	# Сид матча выбирает отображение: внутри симуляции случайность только от этого сида.
	var match_seed: int = randi()
	_sim = MatchSim.new(config, match_seed, player_count, 1)
	if is_logging_enabled:
		_logger = _create_logger(match_seed)
	_sim.command_failed.connect(_on_sim_command_failed)
	_sim.match_finished.connect(_on_sim_match_finished)
	_sim.round_started.connect(_on_sim_round_started)
	_sim.phase_changed.connect(_on_sim_phase_changed)
	_sim.player_eliminated.connect(_on_sim_player_eliminated)
	_hud.set_player_count(player_count)
	_sim.start()
	_shop_panel.setup(_sim, _human())


func _create_logger(match_seed: int) -> MatchLogger:
	var stamp: String = Time.get_datetime_string_from_system(false, true)
	var file_name: String = "%s_seed%d.jsonl" % [stamp.replace(":", "-").replace(" ", "_"),
			match_seed]
	var path: String = ProjectSettings.globalize_path(LIVE_LOG_DIR).path_join(file_name)
	return MatchLogger.new(_sim, path, "live", {"seed": match_seed, "started_at": stamp})


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
	_my_view.is_under_siege = _sim.siege_leader == HUMAN_INDEX
	var multiplier: int = _sim.config.get_breach_multiplier(_sim.round_number)
	_my_view.breach_multiplier = multiplier
	_opponent_view.breach_multiplier = multiplier
	_shop_panel.visible = is_prep and me.is_alive
	_shop_panel.refresh(me.field.get_tower(_selected_tower_id))
	_refresh_opponent_view()
	_fade_left_half_on_change()
	_hud.refresh(_sim, HUMAN_INDEX)
	_update_toast()


## Левая половина в волне: поле соперника, а в бою с призраком — поле призрака.
func _refresh_opponent_view() -> void:
	_opponent_view.visible = not _shop_panel.visible
	var opponent: PlayerState = _opponent()
	if opponent != null:
		_opponent_view.show_field(opponent.field, _sim.config,
				"Поле соперника: %s · туда идёт ваша армия" % opponent.display_name)
		_opponent_view.hero_hp = opponent.hero_hp
		return
	if _sim.ghost_target == HUMAN_INDEX and _sim.ghost_field != null:
		var source: PlayerState = _sim.players[_sim.ghost_source]
		_opponent_view.show_field(_sim.ghost_field, _sim.config,
				"Призрак (копия: %s) · туда идёт ваша армия" % source.display_name)
		_opponent_view.hero_hp = source.hero_hp
		return
	_opponent_view.visible = false


## Магазин и поле соперника сменяют друг друга плавно, а не щелчком.
func _fade_left_half_on_change() -> void:
	if _shop_panel.visible == _was_prep_shown:
		return
	_was_prep_shown = _shop_panel.visible
	_menu_slot.modulate.a = 0.0
	var tween: Tween = _menu_slot.create_tween()
	tween.set_ignore_time_scale()
	tween.tween_property(_menu_slot, "modulate:a", 1.0, HALF_FADE_SECONDS)


func _update_toast() -> void:
	_toast_time_left = maxf(0.0, _toast_time_left - get_process_delta_time())
	_toast_label.modulate.a = clampf(_toast_time_left, 0.0, 1.0)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.reset_size()
	_toast_label.position = Vector2((size.x - _toast_label.size.x) / 2.0, size.y - 90.0)
	_toast_time_left = TOAST_SECONDS


func _show_banner(text: String, color: Color = UiFx.BANNER_COLOR, subtitle: String = "") -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = UiFx.show_banner(_overlay, text, color, subtitle)


func _human() -> PlayerState:
	return _sim.players[HUMAN_INDEX]


func _opponent() -> PlayerState:
	var index: int = _sim.opponent_of[HUMAN_INDEX]
	return _sim.players[index] if index != MatchSim.GHOST else null


func _apply_time_scale() -> void:
	Engine.time_scale = 0.0 if _is_paused else float(SPEEDS[_speed_index])
	_hud.set_paused(_is_paused)
	_hud.set_speed(SPEEDS[_speed_index])


func _show_game_over() -> void:
	if _end_layer.visible:
		return
	_end_panel.show_results(_sim.players, HUMAN_INDEX)
	_end_layer.visible = true
	UiFx.pop_in(_end_panel)
	_sound_bank.play(&"siege" if _human().place != 1 else &"round", 0.0)


func _on_command_requested(command: SimCommand) -> void:
	_sim.queue_command(HUMAN_INDEX, command)


## Нажатие на башню выделяет её, повторное нажатие на выделенную — поворачивает.
func _on_my_view_tower_tapped(tower_id: int) -> void:
	if tower_id != 0 and tower_id == _selected_tower_id:
		_sim.queue_command(HUMAN_INDEX, RotateTowerCommand.new(tower_id))
		return
	_selected_tower_id = tower_id


func _on_view_sound_requested(sound_id: StringName) -> void:
	_sound_bank.play(sound_id)


func _on_hud_pause_pressed() -> void:
	_is_paused = not _is_paused
	_apply_time_scale()
	_sound_bank.play(&"click")


func _on_hud_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_time_scale()
	_sound_bank.play(&"click")


func _on_hud_sound_pressed() -> void:
	SoundBank.set_muted(not SoundBank.is_muted())
	_hud.set_muted(SoundBank.is_muted())
	_sound_bank.play(&"click")


func _on_sim_command_failed(player_index: int, reason: String) -> void:
	if player_index == HUMAN_INDEX:
		_show_toast(reason)


func _on_sim_round_started(round_number: int) -> void:
	if not _sim.is_siege_round(round_number):
		_show_banner("Раунд %d" % round_number)
		_sound_bank.play(&"round", 0.0)
		return
	var subtitle: String = "Двое слабейших атакуют лидера"
	if _sim.siege_leader == HUMAN_INDEX:
		subtitle = "На вас идут сразу двое!"
	elif _sim.siege_attackers.has(HUMAN_INDEX):
		subtitle = "Вы вместе с союзником атакуете лидера"
	_show_banner("ОСАДА!", COLOR_SIEGE, "Раунд %d · %s" % [round_number, subtitle])
	_sound_bank.play(&"siege", 0.0)


func _on_sim_phase_changed(phase: MatchSim.Phase) -> void:
	if phase == MatchSim.Phase.WAVE:
		_show_banner("Волна!")
		_sound_bank.play(&"wave", 0.0)


func _on_sim_player_eliminated(player: PlayerState) -> void:
	if player.index == HUMAN_INDEX:
		_show_game_over()
	else:
		_show_toast("%s выбыл, место %d" % [player.display_name, player.place])


func _on_sim_match_finished() -> void:
	_show_game_over()


func _on_end_panel_again_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MATCH)


func _on_end_panel_menu_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

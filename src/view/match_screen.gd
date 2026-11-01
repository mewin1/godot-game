class_name MatchScreen
extends Control
## Экран матча без камеры: сверху панель (MatchHud), ниже две половины.
## Подготовка: меню (магазин) + своё поле. Волна: поле соперника + своё поле.
## Широкий экран — половины слева/справа, высокий (телефон) — сверху/снизу (автоматически).
## Крутит симуляцию с фиксированным тиком и передаёт в неё команды игрока.

const CONFIG_PATH: String = "res://data/game_config.tres"
const VIGNETTE_SHADER: Shader = preload("res://assets/shaders/vignette.gdshader")
const END_PANEL_SCENE: PackedScene = preload("res://scenes/match_end_panel.tscn")
## Логи живых матчей (для разработки: папка проекта, в git не попадает).
const LIVE_LOG_DIR: String = "res://logs/live"
const HUMAN_INDEX: int = 0
const TOAST_SECONDS: float = 2.0
const SUMMARY_SECONDS: float = 4.0
const TOAST_FONT_SIZE: int = 24
const HALF_FADE_SECONDS: float = 0.35
## Не больше стольких тиков за кадр — чтобы игра не «догоняла» рывком после подвисания.
const MAX_TICKS_PER_FRAME: int = 5
const COLOR_BACKGROUND: Color = Color(0.045, 0.075, 0.115)
const COLOR_TOAST: Color = Color(1.0, 0.8, 0.45)
const COLOR_SIEGE: Color = Color(1.0, 0.45, 0.35)
const SPEEDS: Array[int] = [1, 2]
## Игроков в лобби: вы + боты.
@export var player_count: int = 6
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
var _was_enraged: bool = false
## В каком раунде выбыл каждый игрок (индекс → раунд) — для таблицы итогов.
var _elimination_rounds: Dictionary[int, int] = {}

var _court: PreparationCourt
var _hud: MatchHud
var _halves: BoxContainer
var _menu_slot: Control
var _right_column: VBoxContainer
var _shop_panel: ShopPanel
var _opponent_view: FieldView
var _inventory: InventoryBar
var _idol_slots: Array[IdolSlot] = []
var _watched_player_index: int = -1
var _my_view: FieldView
var _overlay: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _end_layer: Control
var _end_panel: MatchEndPanel
var _hero_select: HeroSelectPanel
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
		get_window().content_scale_size = ScreenFit.LANDSCAPE
	_halves.vertical = false


#region Построение интерфейса

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = DuskTheme.create()
	var background: ColorRect = ColorRect.new()
	background.color = COLOR_BACKGROUND
	_add_full_rect(self, background)
	_court = PreparationCourt.new()
	_court.visible = false
	_add_full_rect(self, _court)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	_add_full_rect(self, root_box)
	root_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud = MatchHud.new()
	_hud.pause_pressed.connect(_on_hud_pause_pressed)
	_hud.speed_pressed.connect(_on_hud_speed_pressed)
	_hud.sound_pressed.connect(_on_hud_sound_pressed)
	_hud.skill_pressed.connect(_on_hud_skill_pressed)
	_hud.hero_info_pressed.connect(_on_hud_hero_info_pressed)
	_hud.player_chip_pressed.connect(_on_hud_player_chip_pressed)
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
	_hero_select = HeroSelectPanel.new()
	_hero_select.visible = false
	_hero_select.hero_chosen.connect(_on_hero_select_hero_chosen)
	add_child(_hero_select)
	_hero_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	vignette_material.set_shader_parameter("strength", 0.16)
	vignette.material = vignette_material
	_add_full_rect(self, vignette)


func _build_halves() -> void:
	_menu_slot = Control.new()
	_make_half(_menu_slot)
	_menu_slot.size_flags_stretch_ratio = 0.70
	var left_column: VBoxContainer = VBoxContainer.new()
	_menu_slot.add_child(left_column)
	left_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_column.offset_left = 12
	left_column.offset_right = -8
	left_column.offset_bottom = -12
	_shop_panel = ShopPanel.new()
	_shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_panel.command_requested.connect(_on_command_requested)
	left_column.add_child(_shop_panel)
	_inventory = InventoryBar.new()
	_inventory.command_requested.connect(_on_command_requested)
	_inventory.tower_selected.connect(_on_reserve_tower_selected)
	left_column.add_child(_inventory)
	_opponent_view = FieldView.new()
	_opponent_view.has_atmosphere = true
	_opponent_view.preparation_court = _court
	_opponent_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opponent_view.sound_requested.connect(_on_view_sound_requested)
	_menu_slot.add_child(_opponent_view)
	var right: VBoxContainer = VBoxContainer.new()
	_right_column = right
	_make_half(right)
	right.size_flags_stretch_ratio = 1.30
	_my_view = FieldView.new()
	_my_view.has_atmosphere = true
	_my_view.is_own_field = true
	_my_view.preparation_court = _court
	_my_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_my_view)
	_shop_panel.mount_selection(_my_view)
	_my_view.command_requested.connect(_on_command_requested)
	_my_view.tower_tapped.connect(_on_my_view_tower_tapped)
	_my_view.sound_requested.connect(_on_view_sound_requested)
	var bottom_row: HBoxContainer = HBoxContainer.new()
	right.add_child(bottom_row)
	var idols: HBoxContainer = HBoxContainer.new()
	idols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idols.alignment = BoxContainer.ALIGNMENT_CENTER
	idols.add_theme_constant_override("separation", 8)
	bottom_row.add_child(idols)
	for i: int in 3:
		var slot: IdolSlot = IdolSlot.new()
		slot.slot_index = i
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.custom_minimum_size = Vector2(78, 72)
		slot.command_requested.connect(_on_command_requested)
		idols.add_child(slot)
		_idol_slots.append(slot)
	var hero_dock: PanelContainer = PanelContainer.new()
	hero_dock.add_theme_stylebox_override("panel", DuskTheme.panel(
			Color("0c1823c9"), Color("71634e99"), 5))
	hero_dock.custom_minimum_size.x = 310
	bottom_row.add_child(hero_dock)
	var hero_row: HBoxContainer = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 5)
	hero_dock.add_child(hero_row)
	_hud.move_hero_controls(hero_row)


func _make_half(half: Control) -> void:
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.clip_contents = true
	_halves.add_child(half)


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.theme_type_variation = &"CardPanelActive"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	_overlay.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast_label.add_theme_color_override("font_color", COLOR_TOAST)
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)


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
	_end_panel.report_pressed.connect(_shop_panel.open_battle_report)
	center.add_child(_end_panel)

#endregion


func _start_match() -> void:
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	# Сид матча выбирает отображение: внутри симуляции случайность только от этого сида.
	var match_seed: int = randi()
	_sim = MatchSim.new(config, match_seed, player_count, 1, ScenePaths.requested_teams)
	if is_logging_enabled:
		_logger = _create_logger(match_seed)
	_sim.command_failed.connect(_on_sim_command_failed)
	_sim.match_finished.connect(_on_sim_match_finished)
	_sim.round_started.connect(_on_sim_round_started)
	_sim.round_finished.connect(_on_sim_round_finished)
	_sim.phase_changed.connect(_on_sim_phase_changed)
	_sim.player_eliminated.connect(_on_sim_player_eliminated)
	_sim.hero_event.connect(_on_sim_hero_event)
	_hud.set_player_count(player_count)
	_sim.start_with_hero_select()
	_shop_panel.setup(_sim, _human())
	_my_view.editing_player = _human()
	if _sim.phase == MatchSim.Phase.HERO_SELECT:
		_hero_select.visible = true
		_hero_select.show_offers(_human().hero_offers, _sim.active_gods)


func _create_logger(match_seed: int) -> MatchLogger:
	var stamp: String = Time.get_datetime_string_from_system(false, true)
	var file_name: String = "%s_seed%d.jsonl" % [stamp.replace(":", "-").replace(" ", "_"),
			match_seed]
	var path: String = ProjectSettings.globalize_path(LIVE_LOG_DIR).path_join(file_name)
	return MatchLogger.new(_sim, path, "live", {"seed": match_seed, "started_at": stamp})


func _step_simulation(delta: float) -> void:
	var tick_seconds: float = 1.0 / _sim.config.ticks_per_second
	var speed: int = SPEEDS[_speed_index] if _sim.phase == MatchSim.Phase.WAVE else 1
	_accumulator += delta * speed
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
	if _sim.phase == MatchSim.Phase.HERO_SELECT:
		_refresh_hero_select(me)
		return
	var is_prep: bool = _sim.phase == MatchSim.Phase.PREP
	_court.visible = true
	_court.split = not (is_prep and me.is_alive)
	_hud.set_preparation(_court.visible)
	_menu_slot.size_flags_stretch_ratio = 0.64 if is_prep else 1.0
	_right_column.size_flags_stretch_ratio = 1.36 if is_prep else 1.0
	_opponent_view.offset_bottom = -(_right_column.size.y - _my_view.size.y)
	if me.get_owned_tower(_selected_tower_id) == null or not is_prep:
		_selected_tower_id = 0
	_my_view.show_field(me.field, _sim.config, "Ваше поле")
	_my_view.hero_hp = me.hero_hp
	_my_view.can_edit = is_prep and me.is_alive
	_my_view.selected_tower_id = _selected_tower_id
	_my_view.is_under_siege = _sim.siege_leader == HUMAN_INDEX and me.is_alive \
			and _sim.phase != MatchSim.Phase.OVER
	_shop_panel.visible = is_prep and me.is_alive
	_shop_panel.refresh(me.get_owned_tower(_selected_tower_id))
	_inventory.visible = is_prep and me.is_alive
	_inventory.refresh(me, is_prep and me.is_alive)
	for i: int in _idol_slots.size():
		_idol_slots[i].refresh(me.field.idols[i], is_prep and me.is_alive,
				_sim.config.ticks_per_second)
	var playback: int = _sim.get_battle_speed() * SPEEDS[_speed_index]
	_my_view.playback_speed = playback
	_opponent_view.playback_speed = playback
	_refresh_opponent_view()
	_fade_left_half_on_change()
	_hud.refresh(_sim, HUMAN_INDEX)
	_announce_enrage(me.field.is_enraged)
	_update_toast()


## Пока выбирают героя: своё поле, таймер выбора; магазин и поле соперника скрыты.
func _refresh_hero_select(me: PlayerState) -> void:
	_my_view.show_field(me.field, _sim.config, "Ваше поле")
	_my_view.hero_hp = me.hero_hp
	_my_view.can_edit = false
	_shop_panel.visible = false
	_opponent_view.visible = false
	_hud.refresh(_sim, HUMAN_INDEX)
	var ticks_left: float = float(_sim.get_phase_ticks_left())
	_hero_select.set_seconds_left(-1 if _sim.config.prep_requires_ready else
			ceili(ticks_left / _sim.config.ticks_per_second))
	_update_toast()


## Левая половина в волне: поле соперника, а в бою с призраком — поле призрака.
func _refresh_opponent_view() -> void:
	_opponent_view.visible = not _shop_panel.visible
	if _watched_player_index >= 0 and _sim.phase == MatchSim.Phase.WAVE:
		var watched: PlayerState = _sim.players[_watched_player_index]
		_opponent_view.show_field(watched.field, _sim.config,
				"Наблюдение: " + watched.display_name)
		_opponent_view.hero_hp = watched.hero_hp
		return
	var opponent: PlayerState = _opponent()
	if opponent != null:
		var hero_name: String = " (%s)" % opponent.hero.display_name if opponent.hero != null else ""
		_opponent_view.show_field(opponent.field, _sim.config,
				("Соперник: %s%s" % [opponent.display_name, hero_name])
				if not opponent.field.is_wave_done() else "Бой завершён · ждём остальных")
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


func _announce_enrage(is_enraged: bool) -> void:
	if is_enraged and not _was_enraged and _human().is_alive:
		_show_banner("ЯРОСТЬ!", COLOR_SIEGE, "Время волны вышло — мобы ускорились")
		_sound_bank.play(&"wave", 0.0)
	_was_enraged = is_enraged


func _update_toast() -> void:
	_toast_time_left = maxf(0.0, _toast_time_left - get_process_delta_time())
	_toast_panel.modulate.a = clampf(_toast_time_left * 2.0, 0.0, 1.0)


func _show_toast(text: String, seconds: float = TOAST_SECONDS) -> void:
	_toast_label.text = text
	_toast_panel.reset_size()
	_toast_panel.position = Vector2((size.x - _toast_panel.size.x) / 2.0,
			size.y - _toast_panel.size.y - 40.0)
	_toast_time_left = seconds


func _show_banner(text: String, color: Color = UiFx.BANNER_COLOR, subtitle: String = "") -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = UiFx.show_banner(_overlay, text, color, subtitle)


func _on_hero_select_hero_chosen(offer_index: int) -> void:
	_sim.queue_command(HUMAN_INDEX, ChooseHeroCommand.new(offer_index))
	_sound_bank.play(&"merge")


func _on_hud_hero_info_pressed() -> void:
	_show_hero_info(_human())


func _on_hud_player_chip_pressed(player_index: int) -> void:
	if player_index < _sim.players.size():
		if _sim.phase == MatchSim.Phase.WAVE and player_index != HUMAN_INDEX:
			_watched_player_index = player_index
		else:
			_show_hero_info(_sim.players[player_index])


## Тост с героем игрока: имя, пассивка, навык.
func _show_hero_info(player: PlayerState) -> void:
	var hero: HeroData = player.hero
	if hero == null:
		return
	var prefix: String = "" if player.index == HUMAN_INDEX else "%s: " % player.display_name
	var lines: PackedStringArray = [prefix + hero.display_name, hero.get_passive_text()]
	if hero.skill != null:
		lines.append("Навык «%s» (%s): %s" % [hero.skill.display_name,
				hero.skill.get_timing_text(), hero.skill.description])
	_show_toast("\n".join(lines), SUMMARY_SECONDS)


func _on_hud_skill_pressed() -> void:
	_sim.queue_command(HUMAN_INDEX, UseHeroSkillCommand.new())
	_sound_bank.play(&"click")


## Сообщения героя: свои — тостом; навык соперника, задевший вас, — тоже.
func _on_sim_hero_event(player_index: int, message: String) -> void:
	if player_index == HUMAN_INDEX:
		_show_toast(message, SUMMARY_SECONDS)
		_sound_bank.play(&"skill", 0.0)
		return
	var attacker: PlayerState = _sim.players[player_index]
	var skill: HeroSkillData = attacker.hero.skill if attacker.hero != null else null
	if skill == null or not skill.effect.affects_opponents():
		return
	if _sim.get_army_target_fields(player_index).has(_human().field):
		_show_toast("%s (%s): %s" % [attacker.display_name, attacker.hero.display_name, message])


func _human() -> PlayerState:
	return _sim.players[HUMAN_INDEX]


func _opponent() -> PlayerState:
	if _sim.opponent_of.is_empty():
		return null
	var index: int = _sim.opponent_of[HUMAN_INDEX]
	return _sim.players[index] if index != MatchSim.GHOST else null


func _apply_time_scale() -> void:
	Engine.time_scale = 0.0 if _is_paused else 1.0
	_hud.set_paused(_is_paused)
	_hud.set_speed(SPEEDS[_speed_index])


## Таблица итогов. Вызывается отложенно: в одном раунде могут выбыть несколько игроков,
## и места раздаются всем сразу — показываем, когда раздали всё.
func _show_game_over() -> void:
	_end_panel.show_results(_sim.players, HUMAN_INDEX, _elimination_rounds)
	if _end_layer.visible:
		return
	_end_layer.visible = true
	UiFx.pop_in(_end_panel)
	_sound_bank.play(&"siege" if _human().place != 1 else &"round", 0.0)


func _on_command_requested(command: SimCommand) -> void:
	_sim.queue_command(HUMAN_INDEX, command)


## ЛКМ только выделяет; поворот обрабатывается ПКМ на самой фигуре.
func _on_my_view_tower_tapped(tower_id: int) -> void:
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


## Сводка после волны: сколько сняла ваша армия и сколько потеряли вы.
func _on_sim_round_finished(round_number: int) -> void:
	var me: PlayerState = _human()
	if not me.is_alive:
		return
	_shop_panel.show_battle_report(me.field.battle_report, round_number, me.army_damage_dealt)
	var lines: PackedStringArray = []
	var target: String = _round_target_name()
	if target == "":
		lines.append("Бой с призраком: урон армии не засчитывается")
	else:
		lines.append("Ваша армия сняла %d HP у: %s" % [me.army_damage_dealt, target])
	var lost: int = me.hp_lost_this_round
	lines.append("Вы потеряли %d HP" % lost if lost > 0 else "Терем устоял без потерь")
	if me.army.rage_percent > 0:
		lines.append("Армия не дошла — в следующем раунде злее: +%d%% HP" % me.army.rage_percent)
	_show_toast("\n".join(lines), SUMMARY_SECONDS)


## Кого атаковала ваша армия в этом раунде (пусто — призрака).
func _round_target_name() -> String:
	if _sim.siege_leader == HUMAN_INDEX:
		var names: PackedStringArray = []
		for index: int in _sim.siege_attackers:
			names.append(_sim.players[index].display_name)
		return " и ".join(names)
	var opponent: PlayerState = _opponent()
	return opponent.display_name if opponent != null else ""


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
	if phase == MatchSim.Phase.PREP:
		_watched_player_index = -1
	if phase != MatchSim.Phase.HERO_SELECT and _hero_select.visible:
		_hero_select.visible = false
		var hero: HeroData = _human().hero
		if hero != null:
			_show_banner(hero.display_name, UiFx.BANNER_COLOR, hero.description)
	if phase == MatchSim.Phase.WAVE:
		_show_banner("Волна!")
		_sound_bank.play(&"wave", 0.0)


func _on_sim_player_eliminated(player: PlayerState) -> void:
	_elimination_rounds[player.index] = _sim.round_number
	if player.index == HUMAN_INDEX:
		_show_game_over.call_deferred()
	elif _human().is_alive:
		_show_toast("%s выбыл, место %d" % [player.display_name, player.place])


func _on_sim_match_finished() -> void:
	_show_game_over.call_deferred()


func _on_end_panel_again_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MATCH)


func _on_end_panel_menu_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


func _on_reserve_tower_selected(tower_id: int) -> void:
	_selected_tower_id = tower_id


## Перехватывает ПКМ до стандартной отмены drag-and-drop в Godot.
func _input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not get_viewport().gui_is_dragging():
		return
	var value: Variant = get_viewport().gui_get_drag_data()
	if value is DragPayload:
		var payload: DragPayload = value
		if payload.data != null:
			payload.rotate_preview()
			get_viewport().set_input_as_handled()

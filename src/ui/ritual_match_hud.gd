class_name RitualMatchHud
extends MatchHud
## Существующая шапка и нижний блок героя PvP; меняется только источник состояния.

## Умение, чей знак стоит на кнопке (-1 — ещё нет).
var _skill_icon_kind: int = -1
var _portrait_path: String = ""
## Ширина имени героя: в нижнем доке забега уже, чем у прежнего блока героя.
var hero_name_width: float = 185.0
## Док забега: частокол — плитка с числом и клавишей (critique_2 п. 23); null — прежняя кнопка.
var palisade_tile: RitualActionTile
var _pause_mark: RitualPauseMark
## Значок фазы у таймера (плейтест 19 ноября): солнце днём, луна ночью — вместо «рассвет через».
var _phase_icon: TextureRect
const DAY_ICON: Texture2D = preload("res://assets/ui/ritual/phase_day.svg")
const NIGHT_ICON: Texture2D = preload("res://assets/ui/ritual/phase_night.svg")


func _init() -> void:
	super()
	_chip_row.hide()
	_speed_button.hide()
	_sound_button.hide()
	_pause_mark = RitualPauseMark.new()
	_pause_mark.name = "PauseMark"
	_pause_mark.hide()
	_phase_icon = TextureRect.new()
	_phase_icon.name = "PhaseIcon"
	_phase_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_phase_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_phase_icon.custom_minimum_size = Vector2(26, 26)
	_phase_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_phase_icon.hide()


func refresh_ritual(trial: RitualTrial, paused: bool) -> void:
	if trial.settings.is_endless():
		# Днём — день перед ночью N, ночью — ночь N; слово «Обряд» и «ночь 3» днём путали (critique_2 п. 21).
		_round_label.text = "%s %d" % ["Ночь" if trial.settings.nights.is_night(trial.tick_count) else "День",
				trial.current_night()]
	else:
		var cycle: int = mini(trial.tick_count / trial.settings.cycle_ticks + 1, trial.settings.cycles)
		_round_label.text = "Обряд · %d / %d" % [cycle, trial.settings.cycles]
	var seconds: int = trial.tick_count / trial.settings.combat.ticks_per_second
	_phase_label.text = "%s · %d:%02d" % [trial.settings.period_name(trial.tick_count), seconds / 60, seconds % 60]
	if trial.settings.is_endless():
		# Забегу важно, сколько осталось до ночи или рассвета, а не сколько прошло (docs/37 UI-1).
		var nights: RitualNightRules = trial.settings.nights
		var night: int = nights.night_index_at(trial.tick_count)
		var at_night: bool = nights.is_night(trial.tick_count)
		var left: int = ceili(float((nights.night_end(night) if at_night else nights.night_start(night))
				- trial.tick_count) / trial.settings.combat.ticks_per_second)
		_phase_label.text = "%d:%02d" % [left / 60, left % 60]
		_phase_icon.texture = NIGHT_ICON if at_night else DAY_ICON
		_phase_icon.tooltip_text = "%s через %d:%02d" % ["Рассвет" if at_night else "Ночь", left / 60, left % 60]
		_phase_label.tooltip_text = _phase_icon.tooltip_text
		_phase_label.mouse_filter = Control.MOUSE_FILTER_STOP
	# Пауза — значком у таймера (critique_3 п. 45), а не словом. Таймер переезжает в шапку забега
	# после _init — значок ставится рядом с ним там, где он сейчас.
	if _pause_mark.get_parent() != _phase_label.get_parent():
		if _pause_mark.get_parent() != null:
			_pause_mark.get_parent().remove_child(_pause_mark)
		_phase_label.add_sibling(_pause_mark)
		if _phase_icon.get_parent() != null:
			_phase_icon.get_parent().remove_child(_phase_icon)
		_phase_label.get_parent().add_child(_phase_icon)
		_phase_label.get_parent().move_child(_phase_icon, _phase_label.get_index())
	_phase_icon.visible = trial.settings.is_endless() and trial.phase == RitualTrial.Phase.RUNNING
	_pause_mark.visible = trial.settings.is_endless() and paused and trial.phase == RitualTrial.Phase.RUNNING
	if trial.phase == RitualTrial.Phase.PREP:
		_phase_label.text = "Подготовка"
	# Забег: HP принадлежит герою в сторожке перед теремом (docs/34 §4, docs/36 §1).
	var hero: RitualHeroData = trial.hero()
	# Имя героя уже в заголовке блока: «Соловей · 45» читалось как «Соловей 45» (critique_2 п. 22).
	_hp_label.text = "%d/%d" % [trial.hp, trial.max_hp()] if trial.settings.is_endless() else str(trial.hp)
	_gold_label.text = str(trial.gold)
	(_income_label.get_parent() as Control).hide()
	_hero_name.text = hero.display_name if hero != null else "Илья Муромец"
	_hero_name.add_theme_font_size_override("font_size", 18)
	_hero_name.custom_minimum_size.x = hero_name_width
	var portrait: String = hero.portrait if hero != null else "res://data/visuals/portraits/ilya.tres"
	if portrait != _portrait_path:
		_portrait_path = portrait
		_hero_portrait.texture = load(portrait) as Texture2D
	var skill: String = hero.skill_name if hero != null else "Удар Ильи"
	# Знак умения (хвост critique_3 п. 51): тёмный силуэт на янтарной кнопке.
	var skill_kind: RitualHeroData.Skill = hero.skill if hero != null else RitualHeroData.Skill.STRIKE
	if _skill_icon_kind != skill_kind:
		_skill_icon_kind = skill_kind
		_skill_button.icon = RitualIcons.skill(skill_kind)
		_skill_button.add_theme_constant_override("icon_max_width", 20)
		RitualIcons.tint(_skill_button, Color("2a1c10"))
	var wait: int = ceili(float(trial.hero_ready - trial.tick_count) / trial.settings.combat.ticks_per_second)
	# Значок умения + клавиша или секунды (плейтест 19 ноября: имя не влезало — «Варево · го»);
	# имя и описание — в подсказке.
	_skill_button.text = "Q" if trial.tick_count >= trial.hero_ready else "%d с" % wait
	if hero != null and trial.brew_charges > 0:
		_skill_button.text = "×%d" % trial.brew_charges
	_skill_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.tick_count < trial.hero_ready or trial.hero_due >= 0
	_skill_button.tooltip_text = "%s (Q)\n%s\n%s" % [skill, hero.skill_text, hero.passive_text] if hero != null \
			else "%s (Q)\nУказать дорогу. Через 1 с — физический удар по области; не оглушает." % skill
	if hero != null and trial.brew_charges > 0:
		_skill_button.tooltip_text = "Готово зелий: %d\n%s" % [trial.brew_charges, _skill_button.tooltip_text]
	var palisade_tip: String = "Частокол поперёк дороги (F): враги стоят, пока первый тяжёлый не сломает его.\nВ запасе: %d." % trial.palisades
	if trial.walls_mode():
		palisade_tip = ("Частокол поперёк дороги (F): первый подошедший враг упирается, и частокол держит всех " \
				+ "%d с, потом ломается. На дорогах — до %d сразу.\nВ запасе: %d (+%d на рассвете).") % [
				trial.settings.palisade_hold_ticks / trial.settings.combat.ticks_per_second,
				trial.settings.palisade_active_cap, trial.palisades, trial.settings.palisade_dawn_gain]
	if palisade_tile != null:
		palisade_tile.set_state(trial.palisades, trial.palisades <= 0, -1)
		palisade_tile.tooltip_text = palisade_tip
		palisade_tile.disabled = not trial.palisade_free()
		_reserve_button.disabled = palisade_tile.disabled
	else:
		_reserve_button.text = "Частокол · %d · F" % trial.palisades
		_reserve_button.tooltip_text = palisade_tip
		_reserve_button.visible = true
		_reserve_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.palisades <= 0
	set_paused(paused)

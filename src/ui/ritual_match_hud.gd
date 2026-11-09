class_name RitualMatchHud
extends MatchHud
## Существующая шапка и нижний блок героя PvP; меняется только источник состояния.

func _init() -> void:
	super()
	_chip_row.hide()
	_speed_button.hide()
	_sound_button.hide()


func refresh_ritual(trial: RitualTrial, paused: bool) -> void:
	if trial.settings.is_endless():
		_round_label.text = "Обряд · ночь %d" % trial.current_night()
	else:
		var cycle: int = mini(trial.tick_count / trial.settings.cycle_ticks + 1, trial.settings.cycles)
		_round_label.text = "Обряд · %d / %d" % [cycle, trial.settings.cycles]
	var seconds: int = trial.tick_count / trial.settings.combat.ticks_per_second
	_phase_label.text = "%s · %d:%02d" % [trial.settings.period_name(trial.tick_count), seconds / 60, seconds % 60]
	if trial.phase == RitualTrial.Phase.PREP:
		_phase_label.text = "Подготовка"
	# Забег: HP принадлежит Илье в сторожке перед теремом (docs/34 §4).
	_hp_label.text = "Илья · %d" % trial.hp if trial.settings.is_endless() else str(trial.hp)
	_gold_label.text = str(trial.gold)
	(_income_label.get_parent() as Control).hide()
	_hero_name.text = "Илья Муромец"
	_hero_name.add_theme_font_size_override("font_size", 17)
	_hero_name.custom_minimum_size.x = 185
	_hero_portrait.texture = load("res://data/visuals/portraits/ilya.tres") as Texture2D
	_skill_button.text = "Удар Ильи · Q" if trial.tick_count >= trial.hero_ready else "Удар Ильи · %d с" % ceili(float(trial.hero_ready - trial.tick_count) / trial.settings.combat.ticks_per_second)
	_skill_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.tick_count < trial.hero_ready or trial.hero_due >= 0
	_skill_button.tooltip_text = "Указать дорогу. Через 1 с — физический удар по области; не оглушает."
	_reserve_button.text = "Частокол · %d · F" % trial.palisades
	_reserve_button.visible = true
	_reserve_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.palisades <= 0
	set_paused(paused)

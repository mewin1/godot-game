class_name RitualMatchHud
extends MatchHud
## Существующая шапка и нижний блок героя PvP; меняется только источник состояния.

var _portrait_path: String = ""
## Ширина имени героя: в нижнем доке забега уже, чем у прежнего блока героя.
var hero_name_width: float = 185.0


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
	if trial.settings.is_endless():
		# Забегу важно, сколько осталось до ночи или рассвета, а не сколько прошло (docs/37 UI-1).
		var nights: RitualNightRules = trial.settings.nights
		var night: int = nights.night_index_at(trial.tick_count)
		var at_night: bool = nights.is_night(trial.tick_count)
		var left: int = ceili(float((nights.night_end(night) if at_night else nights.night_start(night))
				- trial.tick_count) / trial.settings.combat.ticks_per_second)
		_phase_label.text = "%s · до %s %d:%02d" % [nights.period_name(trial.tick_count),
				"рассвета" if at_night else "ночи", left / 60, left % 60]
	if trial.phase == RitualTrial.Phase.PREP:
		_phase_label.text = "Подготовка"
	# Забег: HP принадлежит герою в сторожке перед теремом (docs/34 §4, docs/36 §1).
	var hero: RitualHeroData = trial.hero()
	_hp_label.text = "%s · %d" % [trial.hero_name(), trial.hp] if trial.settings.is_endless() else str(trial.hp)
	_gold_label.text = str(trial.gold)
	(_income_label.get_parent() as Control).hide()
	_hero_name.text = hero.display_name if hero != null else "Илья Муромец"
	_hero_name.add_theme_font_size_override("font_size", 17)
	_hero_name.custom_minimum_size.x = hero_name_width
	var portrait: String = hero.portrait if hero != null else "res://data/visuals/portraits/ilya.tres"
	if portrait != _portrait_path:
		_portrait_path = portrait
		_hero_portrait.texture = load(portrait) as Texture2D
	var skill: String = hero.skill_name if hero != null else "Удар Ильи"
	var wait: int = ceili(float(trial.hero_ready - trial.tick_count) / trial.settings.combat.ticks_per_second)
	_skill_button.text = "%s · Q" % skill if trial.tick_count >= trial.hero_ready else "%s · %d с" % [skill, wait]
	if hero != null and trial.brew_charges > 0:
		_skill_button.text = "%s · готово ×%d" % [skill, trial.brew_charges]
	_skill_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.tick_count < trial.hero_ready or trial.hero_due >= 0
	_skill_button.tooltip_text = "%s\n%s" % [hero.skill_text, hero.passive_text] if hero != null \
			else "Указать дорогу. Через 1 с — физический удар по области; не оглушает."
	_reserve_button.text = "Частокол · %d · F" % trial.palisades
	_reserve_button.visible = true
	_reserve_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.palisades <= 0
	set_paused(paused)

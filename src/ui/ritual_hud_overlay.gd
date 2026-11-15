class_name RitualHudOverlay
extends Control
## Слой поверх карты забега (docs/37 §9–10): баннеры важных событий (ночь, босс, примета,
## рассвет, веха идола), значки взятых даров в шапке, «ПАУЗА», красная кромка экрана при прорыве
## и при малом здоровье героя, свечение готового умения. Только отображение: всё читается из RitualTrial.

const BANNER_SECONDS: float = 3.2
const BREACH_SECONDS: float = 0.7
const LOW_HP_PERCENT: int = 30
const EDGE: float = 90.0
const GIFT_GLYPHS: Dictionary[int, String] = {
	RitualGiftData.Effect.DAMAGE_ALL: "✦", RitualGiftData.Effect.HERO_TWICE: "⚔",
	RitualGiftData.Effect.FREE_REPAIR: "⚒", RitualGiftData.Effect.DOUBLE_DISCOUNT: "%",
	RitualGiftData.Effect.RANGE_ALL: "◎", RitualGiftData.Effect.RATE_ALL: "»",
	RitualGiftData.Effect.HEAL_ILYA: "♥"}

## Кнопка умения героя: светится, когда готово (docs/37 HER-2).
var skill_button: Button
## Звук готовности умения и баннеров.
var sound_bank: SoundBank
var _banner: PanelContainer
var _banner_title: Label
var _banner_text: Label
var _banner_age: float = BANNER_SECONDS
var _pause: Label
var _gifts: HBoxContainer
var _gift_count: int = -1
var _was_night: bool = false
var _night_seen: int = -1
var _last_hp: int = -1
var _breach_age: float = BREACH_SECONDS
var _low_hp: bool = false
var _clock: float = 0.0
var _skill_ready: bool = false
## Нижний отступ карты (высота дока): полоса босса стоит над ним.
var bottom_inset: float = 0.0
## Живой босс: имя, доля здоровья, неуязвимость (docs/37 BOS-1); пусто — босса нет.
var _boss_name: String = ""
var _boss_share: float = 0.0
var _boss_resist: StringName = &""
var _legend: PanelContainer


func _init() -> void:
	name = "RitualHudOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Баннер без коробки с рамкой (critique.md п. 21): крупный заголовок с тенью и одна строка.
	_banner = PanelContainer.new()
	var soft: StyleBoxFlat = DuskTheme.glass(0.45, 12)
	soft.border_color = Color.TRANSPARENT
	_banner.add_theme_stylebox_override("panel", soft)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(box)
	_banner_title = Label.new()
	_banner_title.theme_type_variation = &"HeaderLabel"
	_banner_title.add_theme_font_size_override("font_size", 34)
	_banner_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_banner_title.add_theme_constant_override("shadow_offset_y", 2)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_title)
	_banner_text = Label.new()
	_banner_text.add_theme_font_size_override("font_size", 18)
	_banner_text.add_theme_color_override("font_color", Color("dfe6ea"))
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.custom_minimum_size.x = 520
	box.add_child(_banner_text)
	_banner.hide()
	# Пауза — лёгкое затемнение карты (critique_2 п. 31); пометка «пауза» — у таймера в шапке.
	_pause = Label.new()
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause)
	_pause.hide()
	_gifts = HBoxContainer.new()
	_gifts.name = "TakenGifts"
	_gifts.add_theme_constant_override("separation", 4)
	_gifts.position = Vector2(12, 58)
	add_child(_gifts)


## Крупная плашка по центру сверху; гаснет сама.
func show_banner(title: String, text: String, color: Color = DuskTheme.GOLD) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_text.text = text
	_banner_text.visible = not text.is_empty()
	_banner_age = 0.0
	_banner.show()
	_banner.reset_size()


## Первый кадр нового забега: прежние ночь, HP и дары не дают баннеров и вспышек.
func reset() -> void:
	_gift_count = -1
	_night_seen = -1
	_last_hp = -1
	_was_night = false
	_breach_age = BREACH_SECONDS
	_banner_age = BANNER_SECONDS
	_banner.hide()


func refresh(trial: RitualTrial, paused: bool, modal: bool, delta: float) -> void:
	_clock += delta
	_banner_age += delta
	_breach_age += delta
	var settings: RitualTrialConfig = trial.settings
	var running: bool = trial.phase == RitualTrial.Phase.RUNNING
	_pause.visible = paused and running and not modal
	_refresh_gifts(trial)
	if running and settings.is_endless():
		_watch_phase(trial)
	if _last_hp >= 0 and trial.hp < _last_hp:
		_breach_age = 0.0
	_last_hp = trial.hp
	_low_hp = running and trial.hp * 100 <= trial.max_hp() * LOW_HP_PERCENT
	_banner.visible = _banner_age < BANNER_SECONDS
	if _banner.visible:
		_banner.modulate.a = clampf((BANNER_SECONDS - _banner_age) / 0.6, 0.0, 1.0)
		_banner.position = Vector2((size.x - _banner.size.x) * 0.5, 104)
	_refresh_skill(trial, running)
	_watch_boss(trial)
	queue_redraw()


func _watch_boss(trial: RitualTrial) -> void:
	_boss_name = ""
	for base: MobState in trial.field.mobs:
		if base.is_alive() and base.data.tags.has(trial.settings.boss_tag):
			_boss_name = base.data.display_name
			_boss_share = clampf(float(base.hp) / maxf(1.0, float(base.max_hp)), 0.0, 1.0)
			_boss_resist = base.resist
			return


## Легенда реакций и меток статусов (docs/37 UI-15): открывается кнопкой «?» в шапке.
func toggle_legend(settings: RitualTrialConfig) -> void:
	if _legend == null:
		_legend = PanelContainer.new()
		_legend.name = "ReactionLegend"
		_legend.add_theme_stylebox_override("panel", DuskTheme.panel(Color(0.04, 0.07, 0.11, 0.96), DuskTheme.GOLD, 12))
		_legend.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_legend)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_legend.add_child(box)
		var title: Label = Label.new()
		title.text = "Метки на врагах и реакции · «?» — закрыть"
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", DuskTheme.GOLD)
		box.add_child(title)
		var marks: Label = Label.new()
		marks.text = "Капля — мокрый · треугольник — горит · ромб — заряд · квадрат — холод (светлый — скован) · крест — проклятие"
		marks.add_theme_font_size_override("font_size", 18)
		box.add_child(marks)
		var seen: Dictionary[String, bool] = {}
		for reaction: ReactionData in settings.combat.reactions:
			if seen.has(reaction.display_name) or reaction.explanation.is_empty():
				continue
			seen[reaction.display_name] = true
			var line: Label = Label.new()
			line.text = "%s — %s" % [reaction.display_name, reaction.explanation]
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = 640
			line.add_theme_font_size_override("font_size", 18)
			box.add_child(line)
		_legend.hide()
	_legend.visible = not _legend.visible
	_legend.reset_size()
	_legend.position = Vector2((size.x - _legend.size.x) * 0.5, 70)


func legend_visible() -> bool:
	return _legend != null and _legend.visible


## Смена ночи и рассвета: баннер с тем, что важно знать сейчас.
func _watch_phase(trial: RitualTrial) -> void:
	var settings: RitualTrialConfig = trial.settings
	var at_night: bool = settings.is_night(trial.tick_count)
	var night: int = trial.current_night()
	if _night_seen < 0:
		_night_seen = night
		_was_night = at_night
		return
	if at_night and not _was_night:
		var lines: PackedStringArray = []
		var color: Color = Color("9fc4ff")
		# Коротко (critique_2 п. 32): баннер стоит над улицами, когда выходят враги; описание
		# приметы — в полосе разведки.
		for pack: RitualPack in trial.plan().packs(night):
			if pack.boss:
				color = Color("ff7a5c")
				lines.append("Босс: %s%s" % [settings.enemies[pack.leader].display_name,
					"" if pack.resist == &"" else " · неуязвим: " + RitualScoutQueue.element_name(pack.resist)])
		var night_omen: RitualOmenData = trial.plan().omen(night)
		if night_omen != null:
			lines.append("Примета: %s" % night_omen.title)
		if trial.street_nights.has(night):
			lines.append("Новый вход в город")
		show_banner("Ночь %d" % night, " · ".join(lines), color)
		if sound_bank != null and color != Color("9fc4ff"):
			sound_bank.play(&"siege", 0.0)
	elif not at_night and _was_night:
		# Одна строка с итогом золота вместо бухгалтерии (critique.md п. 21).
		var lines: PackedStringArray = []
		var tribute: int = trial.tribute_due(trial.nights_survived()) if trial.nights_survived() > 0 else 0
		var earned: int = tribute + trial.last_clean_bonus
		if earned > 0:
			lines.append("+%d золота%s" % [earned, " · чистая ночь" if trial.last_clean_bonus > 0 else ""])
		var next_omen: RitualOmenData = trial.plan().omen(night)
		if next_omen != null:
			lines.append("дальше: %s" % next_omen.title)
		show_banner("Ночь %d отбита" % trial.nights_survived(), " · ".join(lines), Color("ffd98a"))
	_was_night = at_night
	_night_seen = night


func _refresh_gifts(trial: RitualTrial) -> void:
	if trial.gifts_taken.size() == _gift_count:
		return
	if _gift_count >= 0 and trial.gifts_taken.size() > _gift_count:
		var gift: RitualGiftData = trial.settings.gifts[trial.gifts_taken[-1]]
		show_banner("Дар: %s" % gift.display_name, gift.description, Color("f0c869"))
	_gift_count = trial.gifts_taken.size()
	for child: Node in _gifts.get_children():
		_gifts.remove_child(child)
		child.queue_free()
	for index: int in trial.gifts_taken:
		var gift: RitualGiftData = trial.settings.gifts[index]
		var chip: Button = Button.new()
		chip.custom_minimum_size = Vector2(30, 30)
		chip.focus_mode = Control.FOCUS_NONE
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.tooltip_text = "%s\n%s" % [gift.display_name, gift.description]
		if gift.god != &"":
			chip.icon = GodSymbols.get_icon(gift.god)
			chip.expand_icon = true
		else:
			chip.text = GIFT_GLYPHS.get(gift.effect, "✦")
		_gifts.add_child(chip)


func _refresh_skill(trial: RitualTrial, running: bool) -> void:
	if skill_button == null:
		return
	var ready: bool = running and not skill_button.disabled
	if ready and not _skill_ready and sound_bank != null and trial.tick_count > 0:
		sound_bank.play(&"click", 0.0)
	_skill_ready = ready
	var glow: float = 0.5 + 0.5 * sin(_clock * 4.0)
	skill_button.modulate = Color(1.0 + 0.25 * glow, 1.0 + 0.18 * glow, 1.0, 1.0) if ready else Color.WHITE


func _draw() -> void:
	if _pause.visible:
		draw_rect(Rect2(0, 0, size.x, size.y - bottom_inset), Color(0.0, 0.01, 0.03, 0.28))
	if not _boss_name.is_empty():
		_draw_boss_bar()
	var strength: float = 0.0
	if _breach_age < BREACH_SECONDS:
		strength = 0.55 * (1.0 - _breach_age / BREACH_SECONDS)
	if _low_hp:
		strength = maxf(strength, 0.18 + 0.12 * sin(_clock * 3.0))
	if strength <= 0.01:
		return
	var red: Color = Color(0.85, 0.08, 0.05, strength)
	var clear: Color = Color(0.85, 0.08, 0.05, 0.0)
	var w: float = size.x
	var h: float = size.y
	_edge(Rect2(0, 0, w, EDGE), red, red, clear, clear)
	_edge(Rect2(0, h - EDGE, w, EDGE), clear, clear, red, red)
	_edge(Rect2(0, 0, EDGE, h), red, clear, clear, red)
	_edge(Rect2(w - EDGE, 0, EDGE, h), clear, red, red, clear)


## Полоса здоровья босса над доком: имя, неуязвимость, сколько осталось.
func _draw_boss_bar() -> void:
	var width: float = 440.0
	var bar: Rect2 = Rect2(Vector2((size.x - width) * 0.5, size.y - bottom_inset - 26.0), Vector2(width, 12))
	draw_rect(bar.grow(3), Color(0.03, 0.03, 0.04, 0.85))
	draw_rect(Rect2(bar.position, Vector2(width * _boss_share, bar.size.y)), Color("d9533f"))
	draw_rect(bar, Color("f0c869"), false, 1.5)
	var font: Font = get_theme_default_font()
	var title: String = _boss_name
	if _boss_resist != &"":
		title += " · неуязвим: " + RitualScoutQueue.element_name(_boss_resist)
	draw_string(font, bar.position + Vector2(0, -7), title, HORIZONTAL_ALIGNMENT_CENTER, width, 15,
		Color("ffd2b8"))


## Полоса с плавным переходом: цвета углов — левый верх, правый верх, правый низ, левый низ.
func _edge(rect: Rect2, a: Color, b: Color, c: Color, d: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([a, b, c, d]))

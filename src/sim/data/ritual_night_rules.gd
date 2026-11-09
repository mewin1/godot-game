class_name RitualNightRules
extends Resource
## Бесконечный «Обряд» (docs/34 §8, §10): календарь суток и рост силы ночей.
## Первая ночь — после короткого вечера; дальше «ночь n → день → ночь n+1». Числа — заглушки автора.

@export_group("Сутки")
## Вечер перед первой ночью: время на первые постройки.
@export var first_evening_ticks: int = 400
## День между ночами: тихий, без врагов, одинаково короткий.
@export var day_ticks: int = 500
## Последние тики дня (и вечера) — закат, только для названия и света.
@export var dusk_ticks: int = 100
@export var night_ticks: int = 900
## На сколько тиков каждая следующая ночь длиннее прежней.
@export var night_growth_ticks: int = 120
@export var night_max_ticks: int = 2400

@export_group("Сила ночей")
## Бюджет угрозы первой ночи; каждая следующая умножает его на (100 + рост)%.
@export var budget_base: int = 18
@export var budget_growth_percent: int = 14
## Здоровье врагов: каждая ночь ×(100 + рост)% к прежней. Награда за убийство не растёт —
## поэтому нужный урон на монету дохода растёт каждую ночь (docs/34 §10).
@export var hp_growth_percent: int = 9
@export var packs_base: int = 3
## +1 пачка каждые столько ночей.
@export var packs_growth_every: int = 2
@export var packs_max: int = 9
@export var pack_max_size: int = 14
## Промежуток между врагами одной пачки.
@export var pack_spacing_ticks: int = 16
## Пачки начинаются в первые столько процентов ночи; остаток — на добивание.
@export var spread_percent: int = 80
## Ведущий пачки забирает не больше этой доли её бюджета: остальное — свита.
@export var leader_budget_percent: int = 50
@export var enemies: Array[RitualEnemyRule] = []

@export_group("Босс")
## Босс приходит в каждую такую ночь (5, 10, 15…).
@export var boss_every: int = 5
## Индекс босса в RitualTrialConfig.enemies.
@export var boss_enemy: int = 5
## Здоровье босса растёт своим темпом — за каждое появление, а не за ночь, иначе дары
## за победу почти недостижимы (проба темпа, docs/34 §14 шаг 9).
@export var boss_hp_growth_percent: int = 60
## Доля бюджета ночи на свиту босса (сверх обычных пачек).
@export var boss_escort_percent: int = 40
## Стихийный босс неуязвим к одной из этих стихий (бог постройки).
@export var boss_resist_gods: Array[StringName] = []

@export_group("Разведка")
## Сколько ближайших пачек видно в очереди (docs/34 §9: 3, позже 5 и 7 — с ростом города).
@export var scout_packs: int = 3
## Важные угрозы (босс, новый враг) видны за столько ночей, даже если дальше обычной очереди.
@export var warn_nights: int = 2
@export var default_seed: int = 1


func night_length(night: int) -> int:
	return mini(night_max_ticks, night_ticks + maxi(0, night - 1) * night_growth_ticks)


## Тик начала ночи с номером night (1 — первая). Формулой, без кэша: ресурс входит в хэш правил.
func night_start(night: int) -> int:
	return first_evening_ticks + _nights_total(night - 1) + maxi(0, night - 1) * day_ticks


## Сумма длин первых count ночей: арифметическая прогрессия до предела, дальше — предел.
func _nights_total(count: int) -> int:
	if count <= 0:
		return 0
	var growing: int = count
	if night_growth_ticks > 0:
		var below_cap: int = maxi(0, night_max_ticks - night_ticks)
		growing = mini(count, (below_cap + night_growth_ticks - 1) / night_growth_ticks)
	elif night_ticks >= night_max_ticks:
		growing = 0
	var total: int = growing * night_ticks + night_growth_ticks * growing * (growing - 1) / 2
	return total + (count - growing) * night_max_ticks


func night_end(night: int) -> int:
	return night_start(night) + night_length(night)


## Текущая ночь или ближайшая впереди (днём — следующая).
func night_index_at(tick: int) -> int:
	var night: int = 1
	while tick >= night_end(night):
		night += 1
	return night


func completed_nights(tick: int) -> int:
	return night_index_at(tick) - 1


func is_night(tick: int) -> bool:
	return tick >= night_start(night_index_at(tick))


func period_name(tick: int) -> String:
	var night: int = night_index_at(tick)
	if tick >= night_start(night):
		return "Ночь %d" % night
	if night == 1:
		return "Вечер"
	return "Закат" if night_start(night) - tick <= dusk_ticks else "День"


## Время для света: [тик внутри суток, начало заката, начало ночи, номер суток с 0].
## Вечер перед первой ночью — конец обычного дня, чтобы солнце уже стояло низко.
func cycle_view(tick: int) -> Array[int]:
	var night: int = night_index_at(tick)
	var segment_start: int = 0 if night == 1 else night_end(night - 1)
	var day_length: int = night_start(night) - segment_start
	var local: int = tick - segment_start + (day_ticks - day_length)
	return [local, day_ticks - dusk_ticks, day_ticks, night - 1]


## Бюджет угрозы ночи: сложный процент от базы, целыми числами.
func budget(night: int) -> int:
	var value: int = budget_base
	for index: int in maxi(0, night - 1):
		value = value * (100 + budget_growth_percent) / 100
	return value


func hp_percent(night: int) -> int:
	var value: int = 100
	for index: int in maxi(0, night - 1):
		value = value * (100 + hp_growth_percent) / 100
	return value


func pack_count(night: int) -> int:
	return mini(packs_max, packs_base + maxi(0, night - 1) / maxi(1, packs_growth_every))


func boss_hp_percent(night: int) -> int:
	var value: int = 100
	for index: int in maxi(0, night / maxi(1, boss_every) - 1):
		value = value * (100 + boss_hp_growth_percent) / 100
	return value


func is_boss_night(night: int) -> bool:
	return boss_every > 0 and night % boss_every == 0


func rule_for(enemy_index: int) -> RitualEnemyRule:
	for rule: RitualEnemyRule in enemies:
		if rule.enemy_index == enemy_index:
			return rule
	return null

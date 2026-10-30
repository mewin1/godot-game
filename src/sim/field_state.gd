class_name FieldState
extends RefCounted
## Поле одного игрока: путь, сетка, башни и мобы. За тик: появление мобов, движение, выстрелы.
## Чистая логика без нод. Золото за убийства и прорывы копит, а забирает их MatchSim.

signal lightning_fired(from_milli: Vector2i, to_milli: Vector2i)
signal tower_fired(tower: TowerState, mob: MobState)
signal mob_killed(mob: MobState)
signal mob_breached(mob: MobState)
## Матч уже применил осаду, общий предел и остаток HP: для точной подписи потерь.
signal breach_resolved(mob: MobState, actual_damage: int)
## Башня ударила всех вокруг разом (пар бани, сказки кота) — для кольца на экране.
signal tower_pulsed(tower: TowerState)
## Особое событие на поле для отображения: &"strike" (палица), &"silence" (башни опалены),
## &"knockback" (леший отбросил моба), &"heal" (знахарка), &"chest" (сундук Кощея),
## &"hero_heal" (пирожки), &"hero_skill" (прочие навыки героя хозяина поля).
signal effect_played(effect_id: StringName, mob: MobState)

const MILLI: int = 1000
const NEIGHBOR_SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Детёныши колобка появляются цепочкой, чуть позади друг друга.
const SPLIT_SPACING_MILLI: int = 150

var layout: BoardLayout
## Сколько первых клеток пути открыто (зависит от уровня магазина).
var path_length: int = 0
var towers: Array[TowerState] = []
var mobs: Array[MobState] = []
var wave_tick: int = 0
var idols: Array[IdolState] = []
## Время волны вышло: мобы бегут быстрее (см. GameConfig.wave_enrage_speed_percent).
var is_enraged: bool = false
## Правила героя хозяина поля: чужие армии медленнее, леший отбрасывает на середине пути.
var enemy_army_slow_percent: int = 0
var knockback_milli: int = 0
## Башни молчат ещё столько тиков (навык Змея Горыныча соперника).
var silence_ticks_left: int = 0
## Накоплено с последнего сбора: золото за убийства и прорвавшиеся мобы.
var pending_kill_gold: int = 0
var pending_breaches: Array[MobState] = []

var config: GameConfig

var _config: GameConfig
## Клетки пути максимального уровня: на них никогда нельзя строить,
## чтобы удлинение пути не задело поставленные башни.
var _reserved: Dictionary[Vector2i, bool] = {}
var _buildable: Dictionary[Vector2i, bool] = {}
var _occupied: Dictionary[Vector2i, int] = {}
var _spawn_queue: Array[SpawnEntry] = []
var _next_tower_id: int = 1
var _next_mob_id: int = 1
var _split_queue: Array[MobState] = []
var _are_bonuses_dirty: bool = true


func _init(game_config: GameConfig, shop_level: int = 1) -> void:
	_config = game_config
	config = game_config
	layout = game_config.board
	for cell: Vector2i in layout.path_cells:
		_reserved[cell] = true
	set_shop_level(shop_level)
	for i: int in game_config.idol_slots:
		idols.append(IdolState.new())


#region Путь и сетка

## Открывает путь для уровня магазина и пересчитывает клетки, где можно строить.
func set_shop_level(shop_level: int) -> void:
	path_length = layout.get_path_length(shop_level)
	_recalculate_buildable()


func get_active_path() -> Array[Vector2i]:
	return layout.path_cells.slice(0, path_length)


func get_future_path() -> Array[Vector2i]:
	return layout.path_cells.slice(path_length)


func is_buildable(cell: Vector2i) -> bool:
	return _buildable.has(cell)


func get_buildable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _buildable:
		cells.append(cell)
	return cells


## Точка пути (в тысячных клетки) для прогресса: между центрами соседних клеток пути.
func get_path_point(progress: int) -> Vector2i:
	var last: int = path_length - 1
	var index: int = clampi(progress / MILLI, 0, last)
	var from: Vector2i = _cell_center(layout.path_cells[index])
	if index >= last:
		return from
	var to: Vector2i = _cell_center(layout.path_cells[index + 1])
	var fraction: int = progress - index * MILLI
	return from + (to - from) * fraction / MILLI


## Прогресс, на котором моб доходит до героя.
func get_path_end_progress() -> int:
	return (path_length - 1) * MILLI


func get_mob_position(mob: MobState) -> Vector2i:
	return get_path_point(mob.progress)

#endregion


#region Башни

## Можно ли поставить фигуру в эти клетки (клетки башни ignore_tower_id считаются свободными).
func can_place(cells: Array[Vector2i], ignore_tower_id: int = 0) -> bool:
	for cell: Vector2i in cells:
		if not is_buildable(cell):
			return false
		var owner_id: int = _occupied.get(cell, 0)
		if owner_id != 0 and owner_id != ignore_tower_id:
			return false
	return true


func can_place_tower_data(data: TowerData, anchor: Vector2i, rotation: int) -> bool:
	return can_place(TowerState.shape_cells_at(data.shape, anchor, rotation))


## Ставит башню без проверок (проверять can_place заранее).
func add_tower(data: TowerData, anchor: Vector2i, rotation: int) -> TowerState:
	var tower: TowerState = create_tower(data)
	tower.anchor = anchor
	tower.rotation = rotation
	attach_tower(tower)
	return tower


## Создаёт башню с единым id, даже если сначала покупают в резерв.
func create_tower(data: TowerData) -> TowerState:
	var tower: TowerState = TowerState.new()
	tower.id = _next_tower_id
	_next_tower_id += 1
	tower.data = data
	return tower


## Возвращает существующую башню из резерва, сохраняя её состояние.
func attach_tower(tower: TowerState) -> void:
	towers.append(tower)
	_next_tower_id = maxi(_next_tower_id, tower.id + 1)
	_occupy(tower)


## Идол божества или null, если ни одна основа ещё ему не посвящена.
func get_idol(god: StringName) -> IdolState:
	if god == &"":
		return null
	for idol: IdolState in idols:
		if idol.god == god:
			return idol
	return null


## Переносит или поворачивает башню. false — если новое место занято или недоступно.
func move_tower(tower: TowerState, anchor: Vector2i, rotation: int) -> bool:
	var cells: Array[Vector2i] = TowerState.shape_cells_at(tower.data.shape, anchor, rotation)
	if not can_place(cells, tower.id):
		return false
	_free(tower)
	tower.anchor = anchor
	tower.rotation = rotation
	_occupy(tower)
	return true


## Ставит копии башен другого поля (для призрака). Поле должно быть того же уровня пути.
func copy_towers_from(other: FieldState) -> void:
	path_length = other.path_length
	enemy_army_slow_percent = other.enemy_army_slow_percent
	knockback_milli = other.knockback_milli
	_recalculate_buildable()
	for source: TowerState in other.towers:
		var tower: TowerState = add_tower(source.data, source.anchor, source.rotation)
		tower.level = source.level
		tower.enchantment = source.enchantment
		tower.awakening = source.awakening
	for i: int in idols.size():
		var source_idol: IdolState = other.idols[i]
		idols[i] = source_idol.duplicate_state()


func remove_tower(tower: TowerState) -> void:
	_free(tower)
	towers.erase(tower)


func get_tower(tower_id: int) -> TowerState:
	for tower: TowerState in towers:
		if tower.id == tower_id:
			return tower
	return null


func get_tower_at(cell: Vector2i) -> TowerState:
	var tower_id: int = _occupied.get(cell, 0)
	return get_tower(tower_id)


## Сколько клеток открытого пути башня с такими клетками и радиусом достаёт.
func count_path_cells_in_range(cells: Array[Vector2i], range_milli: int) -> int:
	var center: Vector2i = TowerState.center_of(cells)
	var count: int = 0
	for i: int in path_length:
		if _is_in_range(center, _cell_center(layout.path_cells[i]), range_milli):
			count += 1
	return count

#endregion


#region Волна

## Добавляет моба в очередь появления. Порядок при одинаковом тике — порядок добавления.
func schedule_spawn(mob: MobState, spawn_tick: int) -> void:
	var index: int = _spawn_queue.size()
	while index > 0 and _spawn_queue[index - 1].spawn_tick > spawn_tick:
		index -= 1
	_spawn_queue.insert(index, SpawnEntry.new(spawn_tick, mob))


func start_wave() -> void:
	wave_tick = 0
	is_enraged = false
	silence_ticks_left = 0


## Башни поменялись (уровень, место): бонусы соседства пересчитаются перед следующим выстрелом.
func mark_towers_changed() -> void:
	_are_bonuses_dirty = true


func count_alive_mobs() -> int:
	var count: int = 0
	for mob: MobState in mobs:
		if mob.is_alive():
			count += 1
	return count


## Сколько живых юнитов армии игрока sender_index на этом поле.
func count_alive_mobs_of(sender_index: int) -> int:
	var count: int = 0
	for mob: MobState in mobs:
		if mob.is_alive() and mob.sender_index == sender_index:
			count += 1
	return count


## Все живые мобы теряют percent% текущего HP (никого не добивает).
func damage_all_by_percent(percent: int) -> void:
	for mob: MobState in mobs:
		if mob.is_alive():
			mob.hp -= mob.hp * percent / 100
	effect_played.emit(&"strike", null)


## Сообщить отображению о событии героя на этом поле (без влияния на симуляцию).
func play_effect(effect_id: StringName) -> void:
	effect_played.emit(effect_id, null)


## Башни не стреляют ticks тиков (если уже молчат дольше — не укорачивает).
func silence_towers(ticks: int) -> void:
	silence_ticks_left = maxi(silence_ticks_left, ticks)
	effect_played.emit(&"silence", null)


## Ярость: время волны вышло, оставшиеся мобы ускоряются.
func enrage() -> void:
	is_enraged = true


## Волна кончилась — ярость спадает (поле готово к подготовке).
func calm_down() -> void:
	is_enraged = false


func tick() -> void:
	_spawn_due_mobs()
	_move_mobs()
	_heal_mobs()
	_fire_towers()
	_add_split_mobs()
	_remove_finished_mobs()
	wave_tick += 1


func is_wave_done() -> bool:
	return mobs.is_empty() and _spawn_queue.is_empty()


## Все оставшиеся мобы (и не появившиеся) считаются прорвавшимися — при таймауте волны.
func breach_all_remaining() -> void:
	for entry: SpawnEntry in _spawn_queue:
		mobs.append(entry.mob)
	_spawn_queue.clear()
	for mob: MobState in mobs:
		if mob.is_alive():
			_breach(mob)
	mobs.clear()


## По общему пределу оставшиеся отступают без урона и без награды.
func retreat_remaining() -> void:
	mobs.clear()
	_spawn_queue.clear()
	_split_queue.clear()


## Убирает накопленное: вызывает MatchSim после того, как забрал золото и прорывы.
func clear_pending() -> void:
	pending_kill_gold = 0
	pending_breaches.clear()


## Хэш состояния поля для проверки детерминизма.
func add_to_hash(hasher: StateHasher) -> void:
	hasher.add(path_length)
	hasher.add(wave_tick)
	hasher.add(int(is_enraged))
	hasher.add(silence_ticks_left)
	hasher.add(_next_tower_id)
	for idol: IdolState in idols:
		idol.add_to_hash(hasher)
	for tower: TowerState in towers:
		tower.add_to_hash(hasher)
	for mob: MobState in mobs:
		hasher.add_many([mob.id, mob.hp, mob.progress, mob.slow_percent, mob.slow_ticks_left,
				mob.shield_left, mob.heal_cooldown, mob.heal_window_ticks,
				mob.heal_window_percent, mob.speed, mob.armor, mob.max_hp,
				mob.sender_index, mob.charges, mob.charge_ticks_left, mob.burn_damage,
				mob.burn_ticks_left, mob.burn_cooldown, mob.wind_slow_percent, mob.wind_boost_percent])
		hasher.add_string(mob.data.id)
	hasher.add(_spawn_queue.size())
	for entry: SpawnEntry in _spawn_queue:
		hasher.add(entry.spawn_tick)
		hasher.add_string(entry.mob.data.id)
		hasher.add_many([entry.mob.hp, entry.mob.speed, entry.mob.sender_index])

#endregion


func _recalculate_buildable() -> void:
	_buildable.clear()
	var radius: int = _config.build_radius
	for i: int in path_length:
		var path_cell: Vector2i = layout.path_cells[i]
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = path_cell + Vector2i(dx, dy)
				if layout.is_inside(cell) and not _reserved.has(cell):
					_buildable[cell] = true


func _occupy(tower: TowerState) -> void:
	_are_bonuses_dirty = true
	for cell: Vector2i in tower.cells():
		_occupied[cell] = tower.id


func _free(tower: TowerState) -> void:
	_are_bonuses_dirty = true
	for cell: Vector2i in tower.cells():
		_occupied.erase(cell)


func _spawn_due_mobs() -> void:
	while not _spawn_queue.is_empty() and _spawn_queue[0].spawn_tick <= wave_tick:
		var entry: SpawnEntry = _spawn_queue.pop_front()
		var mob: MobState = entry.mob
		mob.id = _next_mob_id
		_next_mob_id += 1
		mob.progress = 0
		mob.previous_progress = 0
		if mob.sender_index >= 0 and enemy_army_slow_percent > 0:
			mob.speed = mob.speed * (100 - enemy_army_slow_percent) / 100
		mobs.append(mob)


func _move_mobs() -> void:
	var end_progress: int = get_path_end_progress()
	for mob: MobState in mobs:
		DivineCombat.apply_wind(self, mob)
		DivineCombat.tick_effects(self, mob)
		if not mob.is_alive():
			continue
		mob.advance()
		if is_enraged:
			mob.progress += mob.current_speed() * _config.wave_enrage_speed_percent / 100
		if mob.data.sprint_from_percent > 0 \
				and mob.progress * 100 >= end_progress * mob.data.sprint_from_percent:
			mob.progress += mob.current_speed() * mob.data.sprint_speed_percent / 100
		if knockback_milli > 0 and not mob.was_knocked_back and mob.progress * 2 >= end_progress:
			mob.was_knocked_back = true
			mob.progress = maxi(0, mob.progress - knockback_milli)
			mob.previous_progress = mob.progress
			effect_played.emit(&"knockback", mob)
		if mob.progress >= end_progress:
			mob.progress = end_progress
			_breach(mob)


func _breach(mob: MobState) -> void:
	mob.is_breached = true
	pending_breaches.append(mob)
	mob_breached.emit(mob)


func _fire_towers() -> void:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	if silence_ticks_left > 0:
		silence_ticks_left -= 1
		return
	for tower: TowerState in towers:
		if not tower.data.attacks:
			continue
		if tower.cooldown_left > 0:
			tower.cooldown_left -= 1
			continue
		if not _fire(tower):
			continue
		# Минус один: тик выстрела тоже входит в перезарядку, период ровно cooldown.
		tower.cooldown_left = get_tower_cooldown(tower) - 1


## Один выстрел башни. false — стрелять не в кого.
func _fire(tower: TowerState) -> bool:
	var center: Vector2i = tower.center_milli()
	var range_milli: int = get_tower_range(tower)
	if tower.data.hits_all_in_range:
		var hit_any: bool = false
		for mob: MobState in mobs:
			if _can_target(tower, center, range_milli, mob):
				_hit(mob, get_tower_damage(tower), tower.data, tower)
				hit_any = true
		if hit_any:
			tower_pulsed.emit(tower)
		return hit_any
	var targets: Array[MobState] = _find_targets(tower, center, range_milli)
	for target: MobState in targets:
		_shoot(tower, target)
	return not targets.is_empty()


## Цели — живые мобы в радиусе, дальше всех прошедшие по пути (при равенстве — меньший id).
func _find_targets(tower: TowerState, center: Vector2i, range_milli: int) -> Array[MobState]:
	var targets: Array[MobState] = []
	for i: int in tower.data.targets_per_shot:
		var best: MobState = null
		for mob: MobState in mobs:
			if targets.has(mob) or not _can_target(tower, center, range_milli, mob):
				continue
			if best == null or mob.progress > best.progress:
				best = mob
		if best == null:
			break
		targets.append(best)
	return targets


## Видит ли башня моба: жив, в радиусе, не летает над ней, не прячется в невидимости.
func _can_target(tower: TowerState, center: Vector2i, range_milli: int, mob: MobState) -> bool:
	if not mob.is_alive():
		return false
	if mob.data.is_flying and not tower.data.can_hit_flying:
		return false
	var position: Vector2i = get_mob_position(mob)
	var reveal: int = mob.data.reveal_radius_milli
	if reveal > 0 and not _is_in_range(center, position, reveal):
		return false
	return _is_in_range(center, position, range_milli)


func _shoot(tower: TowerState, target: MobState) -> void:
	var damage: int = get_tower_damage(tower)
	tower_fired.emit(tower, target)
	var target_position: Vector2i = get_mob_position(target)
	_hit(target, damage, tower.data, tower)
	if tower.data.splash_radius_milli <= 0:
		return
	var splash_damage: int = damage * tower.data.splash_percent / 100
	for mob: MobState in mobs:
		if mob == target or not mob.is_alive():
			continue
		var position: Vector2i = get_mob_position(mob)
		if _is_in_range(target_position, position, tower.data.splash_radius_milli):
			_hit(mob, splash_damage, tower.data, tower)


func _hit(mob: MobState, damage: int, data: TowerData, tower: TowerState = null) -> void:
	if data.slow_percent > 0:
		mob.apply_slow(data.slow_percent, data.slow_ticks)
	if tower != null and tower.data.god != &"":
		DivineCombat.hit(self, tower, mob, damage)
	else:
		deal_mob_damage(mob, damage)


## Единственное место награды за смерть, в том числе от горения и цепи.
func deal_mob_damage(mob: MobState, damage: int) -> void:
	if mob.take_damage(damage):
		pending_kill_gold += mob.kill_reward
		mob_killed.emit(mob)
		_queue_split(mob)


## Колобок: при смерти — детёныши на том же месте пути (появятся после выстрелов этого тика).
func _queue_split(parent: MobState) -> void:
	var child_data: MobData = parent.data.split_into
	if child_data == null:
		return
	for i: int in parent.data.split_count:
		var child: MobState = MobState.create(child_data)
		child.max_hp = maxi(1, parent.max_hp * parent.data.split_hp_percent / 100)
		child.hp = child.max_hp
		child.speed = parent.speed
		child.sender_index = parent.sender_index
		child.progress = maxi(0, parent.progress - i * SPLIT_SPACING_MILLI)
		child.previous_progress = child.progress
		_split_queue.append(child)


func _add_split_mobs() -> void:
	for child: MobState in _split_queue:
		child.id = _next_mob_id
		_next_mob_id += 1
		mobs.append(child)
	_split_queue.clear()


## Лечение одной цели не складывается, даже если импульсы лекарей сдвинуты во времени.
func _heal_mobs() -> void:
	for mob: MobState in mobs:
		if mob.heal_window_ticks > 0:
			mob.heal_window_ticks -= 1
			if mob.heal_window_ticks == 0:
				mob.heal_window_percent = 0
		if mob.data.heal_percent > 0 and mob.is_alive():
			mob.heal_cooldown -= 1
	for target: MobState in mobs:
		if not target.is_alive() or target.hp >= target.max_hp:
			continue
		var percent: int = target.heal_window_percent
		for healer: MobState in mobs:
			if healer.is_alive() and healer.data.heal_percent > percent \
					and healer.heal_cooldown <= 0 and _is_in_range(get_mob_position(healer),
					get_mob_position(target), healer.data.heal_radius_milli):
				percent = healer.data.heal_percent
		if percent > target.heal_window_percent:
			_apply_healing(target, percent)
	for healer: MobState in mobs:
		if healer.is_alive() and healer.data.heal_percent > 0 and healer.heal_cooldown <= 0:
			healer.heal_cooldown = healer.data.heal_interval_ticks
			effect_played.emit(&"heal", healer)


func _apply_healing(target: MobState, percent: int) -> void:
	var previous: int = 0
	if target.heal_window_percent > 0:
		previous = maxi(1, target.max_hp * target.heal_window_percent / 100)
	var amount: int = maxi(1, target.max_hp * percent / 100) - previous
	target.hp = mini(target.max_hp, target.hp + amount)
	if target.heal_window_ticks == 0:
		target.heal_window_ticks = _config.ticks_per_second
	target.heal_window_percent = percent


#region Соседство и бонусы

## Урон башни с уровнем и бонусом соседей.
func get_tower_damage(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	var damage: int = _config.get_level_damage(tower.data.damage, tower.level)
	var bonus: int = tower.bonus_damage_percent
	var idol: IdolState = get_idol(tower.data.god)
	if idol != null:
		bonus += idol.damage_percent
	if tower.enchantment == RiteData.Effect.ENCHANT_DAMAGE:
		bonus += _config.enchant_damage_percent
	if tower.awakening == RiteData.Effect.AWAKEN_FOCUS:
		bonus += _config.awakening_power_percent
	return damage * (100 + bonus) / 100


## Перезарядка с бонусом соседей (не меньше 1 тика).
func get_tower_cooldown(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	var rate: int = tower.bonus_fire_rate_percent
	if tower.enchantment == RiteData.Effect.ENCHANT_RATE:
		rate += _config.enchant_rate_percent
	return maxi(1, tower.data.cooldown_ticks * 100 / (100 + rate))


func get_tower_range(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	var reach: int = tower.data.range_milli + tower.bonus_range_milli
	if tower.enchantment == RiteData.Effect.ENCHANT_RANGE:
		reach += _config.enchant_range_milli
	if tower.awakening == RiteData.Effect.AWAKEN_WIDE:
		reach += _config.enchant_range_milli
	return reach


## Соседи башни: постройки, касающиеся её клеток стороной. Порядок — по id (детерминизм).
func get_neighbors(tower: TowerState) -> Array[TowerState]:
	var ids: Array[int] = []
	for cell: Vector2i in tower.cells():
		for side: Vector2i in NEIGHBOR_SIDES:
			var owner_id: int = _occupied.get(cell + side, 0)
			if owner_id != 0 and owner_id != tower.id and not ids.has(owner_id):
				ids.append(owner_id)
	ids.sort()
	var result: Array[TowerState] = []
	for id: int in ids:
		result.append(get_tower(id))
	return result


## Сколько построек каждой школы стоит на поле (слитая считается одной).
func count_schools() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for tower: TowerState in towers:
		counts[tower.data.school] = counts.get(tower.data.school, 0) + 1
	return counts


## Доход от построек (лавки) и бонуса школы «Двор» в конце раунда.
func get_round_income() -> int:
	var total: int = _school_income()
	for tower: TowerState in towers:
		if tower.data.income_per_round > 0:
			total += _config.get_level_damage(tower.data.income_per_round, tower.level)
	return total


## Пересчитывает бонусы всех башен от соседей-усилителей.
func refresh_bonuses() -> void:
	_refresh_bonuses()


func _refresh_bonuses() -> void:
	_are_bonuses_dirty = false
	for tower: TowerState in towers:
		tower.bonus_damage_percent = 0
		tower.bonus_fire_rate_percent = 0
		tower.bonus_range_milli = 0
	_apply_school_bonuses()
	for support: TowerState in towers:
		if not support.data.is_support():
			continue
		var data: TowerData = support.data
		for neighbor: TowerState in get_neighbors(support):
			neighbor.bonus_damage_percent += _config.get_level_damage(
					data.neighbor_damage_percent, support.level)
			neighbor.bonus_fire_rate_percent += _config.get_level_damage(
					data.neighbor_fire_rate_percent, support.level)
			neighbor.bonus_range_milli += _config.get_level_damage(
					data.neighbor_range_milli, support.level)

#endregion


func _apply_school_bonuses() -> void:
	var counts: Dictionary[StringName, int] = count_schools()
	for bonus: SchoolBonusData in _config.school_bonuses:
		var count: int = counts.get(bonus.school, 0)
		var value: int = bonus.get_value(count)
		if value == 0 or bonus.kind == SchoolBonusData.Kind.INCOME:
			continue
		for tower: TowerState in towers:
			if tower.data.school != bonus.school:
				continue
			match bonus.kind:
				SchoolBonusData.Kind.DAMAGE_PERCENT:
					tower.bonus_damage_percent += value
				SchoolBonusData.Kind.FIRE_RATE_PERCENT:
					tower.bonus_fire_rate_percent += value
				SchoolBonusData.Kind.RANGE_MILLI:
					tower.bonus_range_milli += value


func _school_income() -> int:
	var counts: Dictionary[StringName, int] = count_schools()
	var total: int = 0
	for bonus: SchoolBonusData in _config.school_bonuses:
		var count: int = counts.get(bonus.school, 0)
		if bonus.kind == SchoolBonusData.Kind.INCOME:
			total += bonus.get_value(count)
	return total


func _remove_finished_mobs() -> void:
	var alive: Array[MobState] = []
	for mob: MobState in mobs:
		if mob.is_alive():
			alive.append(mob)
	mobs = alive


func _cell_center(cell: Vector2i) -> Vector2i:
	return cell * MILLI + Vector2i(MILLI / 2, MILLI / 2)


func _is_in_range(from: Vector2i, to: Vector2i, range_milli: int) -> bool:
	var delta: Vector2i = to - from
	return delta.x * delta.x + delta.y * delta.y <= range_milli * range_milli


## Запоминает начало отображаемого шага перед несколькими тиками общей перемотки.
func begin_visual_step() -> void:
	for mob: MobState in mobs:
		mob.visual_start_progress = mob.progress


## Интерполяция охватывает весь пройденный участок, а не лишь последний тик из пяти.
func end_visual_step() -> void:
	for mob: MobState in mobs:
		mob.previous_progress = mob.visual_start_progress

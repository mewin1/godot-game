class_name FieldState
extends RefCounted
## Поле одного игрока: путь, сетка, башни и мобы. За тик: появление мобов, движение, выстрелы.
## Чистая логика без нод. Золото за убийства и прорывы копит, а забирает их MatchSim.

signal tower_fired(tower: TowerState, mob: MobState)
signal mob_killed(mob: MobState)
signal mob_breached(mob: MobState)
## Башня ударила всех вокруг разом (пар бани, сказки кота) — для кольца на экране.
signal tower_pulsed(tower: TowerState)
## Особое событие на поле для отображения: &"strike" (палица), &"silence" (башни опалены),
## &"knockback" (леший отбросил моба).
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


func _init(config: GameConfig, shop_level: int = 1) -> void:
	_config = config
	layout = config.board
	for cell: Vector2i in layout.path_cells:
		_reserved[cell] = true
	set_shop_level(shop_level)


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
	var tower: TowerState = TowerState.new()
	tower.id = _next_tower_id
	_next_tower_id += 1
	tower.data = data
	tower.anchor = anchor
	tower.rotation = rotation
	towers.append(tower)
	_occupy(tower)
	return tower


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
	for source: TowerState in other.towers:
		var tower: TowerState = add_tower(source.data, source.anchor, source.rotation)
		tower.level = source.level


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
	for tower: TowerState in towers:
		hasher.add_many([tower.id, tower.anchor.x, tower.anchor.y, tower.rotation, tower.level,
				tower.cooldown_left, tower.invested_total, tower.invested_this_phase])
		hasher.add_string(tower.data.id)
	for mob: MobState in mobs:
		hasher.add_many([mob.id, mob.hp, mob.progress, mob.slow_percent, mob.slow_ticks_left,
				mob.shield_left, mob.heal_cooldown])
	hasher.add(_spawn_queue.size())

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
				_hit(mob, get_tower_damage(tower), tower.data)
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
	_hit(target, damage, tower.data)
	if tower.data.splash_radius_milli <= 0:
		return
	var splash_damage: int = damage * tower.data.splash_percent / 100
	for mob: MobState in mobs:
		if mob == target or not mob.is_alive():
			continue
		var position: Vector2i = get_mob_position(mob)
		if _is_in_range(target_position, position, tower.data.splash_radius_milli):
			_hit(mob, splash_damage, tower.data)


func _hit(mob: MobState, damage: int, data: TowerData) -> void:
	if data.slow_percent > 0:
		mob.apply_slow(data.slow_percent, data.slow_ticks)
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


## Лекари раз в интервал лечат мобов рядом (и себя) на процент их HP.
func _heal_mobs() -> void:
	for healer: MobState in mobs:
		if healer.data.heal_percent <= 0 or not healer.is_alive():
			continue
		healer.heal_cooldown -= 1
		if healer.heal_cooldown > 0:
			continue
		healer.heal_cooldown = healer.data.heal_interval_ticks
		var center: Vector2i = get_mob_position(healer)
		for mob: MobState in mobs:
			if mob.is_alive() and mob.hp < mob.max_hp \
					and _is_in_range(center, get_mob_position(mob), healer.data.heal_radius_milli):
				mob.hp = mini(mob.max_hp, mob.hp + maxi(1, mob.max_hp * healer.data.heal_percent / 100))
		effect_played.emit(&"heal", healer)


#region Соседство и бонусы

## Урон башни с уровнем и бонусом соседей.
func get_tower_damage(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	var damage: int = _config.get_level_damage(tower.data.damage, tower.level)
	return damage * (100 + tower.bonus_damage_percent) / 100


## Перезарядка с бонусом соседей (не меньше 1 тика).
func get_tower_cooldown(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	return maxi(1, tower.data.cooldown_ticks * 100 / (100 + tower.bonus_fire_rate_percent))


func get_tower_range(tower: TowerState) -> int:
	if _are_bonuses_dirty:
		_refresh_bonuses()
	return tower.data.range_milli + tower.bonus_range_milli


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


## Доход от построек (лавки) в конце раунда.
func get_round_income() -> int:
	var total: int = 0
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

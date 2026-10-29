class_name FieldState
extends RefCounted
## Поле одного игрока: путь, сетка, башни и мобы. За тик: появление мобов, движение, выстрелы.
## Чистая логика без нод. Золото за убийства и прорывы копит, а забирает их MatchSim.

signal tower_fired(tower: TowerState, mob: MobState)
signal mob_killed(mob: MobState)
signal mob_breached(mob: MobState)

const MILLI: int = 1000

var layout: BoardLayout
## Сколько первых клеток пути открыто (зависит от уровня магазина).
var path_length: int = 0
var towers: Array[TowerState] = []
var mobs: Array[MobState] = []
var wave_tick: int = 0
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


func tick() -> void:
	_spawn_due_mobs()
	_move_mobs()
	_fire_towers()
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
	for tower: TowerState in towers:
		hasher.add_many([tower.id, tower.anchor.x, tower.anchor.y, tower.rotation, tower.level,
				tower.cooldown_left, tower.invested_total, tower.invested_this_phase])
		hasher.add_string(tower.data.id)
	for mob: MobState in mobs:
		hasher.add_many([mob.id, mob.hp, mob.progress, mob.slow_percent, mob.slow_ticks_left])
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
	for cell: Vector2i in tower.cells():
		_occupied[cell] = tower.id


func _free(tower: TowerState) -> void:
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
		mobs.append(mob)


func _move_mobs() -> void:
	var end_progress: int = get_path_end_progress()
	for mob: MobState in mobs:
		mob.advance()
		if mob.progress >= end_progress:
			mob.progress = end_progress
			_breach(mob)


func _breach(mob: MobState) -> void:
	mob.is_breached = true
	pending_breaches.append(mob)
	mob_breached.emit(mob)


func _fire_towers() -> void:
	for tower: TowerState in towers:
		if tower.cooldown_left > 0:
			tower.cooldown_left -= 1
			continue
		var center: Vector2i = tower.center_milli()
		var target: MobState = _find_target(center, tower.data.range_milli)
		if target == null:
			continue
		_shoot(tower, target)
		# Минус один: тик выстрела тоже входит в перезарядку, период ровно cooldown_ticks.
		tower.cooldown_left = tower.data.cooldown_ticks - 1


## Цель — живой моб в радиусе, дальше всех прошедший по пути (при равенстве — меньший id).
func _find_target(center: Vector2i, range_milli: int) -> MobState:
	var best: MobState = null
	for mob: MobState in mobs:
		if not mob.is_alive():
			continue
		if not _is_in_range(center, get_mob_position(mob), range_milli):
			continue
		if best == null or mob.progress > best.progress:
			best = mob
	return best


func _shoot(tower: TowerState, target: MobState) -> void:
	var damage: int = _config.get_level_damage(tower.data.damage, tower.level)
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

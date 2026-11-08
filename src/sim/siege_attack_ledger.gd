class_name SiegeAttackLedger
extends RefCounted
## Группы отправленной армии, не меняющие общий MobState и правила боя.

class Entry extends RefCounted:
	var mob: MobState
	var held: bool
	var spawn_tick: int

	func _init(unit: MobState, from_reserve: bool, at: int) -> void:
		mob = unit
		held = from_reserve
		spawn_tick = at

var entries: Array[Entry] = []


func record(mob: MobState, held: bool, spawn_tick: int) -> void:
	entries.append(Entry.new(mob, held, spawn_tick))


func breaches(held: bool) -> int:
	var count: int = 0
	for entry: Entry in entries:
		if entry.held == held and entry.mob.is_breached:
			count += 1
	return count


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add(entries.size())
	for entry: Entry in entries:
		hasher.add_many([entry.mob.id, entry.spawn_tick, int(entry.held), int(entry.mob.is_breached)])

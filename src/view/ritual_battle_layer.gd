class_name RitualBattleLayer
extends BattleLayer
## Общие PvP-снаряды, реакции, молнии, попадания и исчезновения.
## Полоски оберега и особые статусы опыта рисует RitualBoard.

const MOB_FLASH_SECONDS: float = 0.8
var _mob_flash_next: Dictionary[int, float] = {}


func _draw_mobs() -> void:
	pass


func _draw_hero_hp(_center: Vector2) -> void:
	pass


## Сторожка - конец главной дороги "Обряда": урон прорыва всплывает у нее.
func _hero_screen_position() -> Vector2:
	var route: Array[Vector2i] = (_field as RitualField).route(0)
	return _milli_to_screen((Vector2(route[route.size() - 1]) + Vector2(0.5, 0.2)) * MILLI)


func _on_field_mob_killed(mob: MobState) -> void:
	var id: StringName = RitualStage3D.UNIT_IDS.get(mob.data.id, &"basic")
	var at: Vector2 = mob_feet_projector.call(mob)
	_spawn_puff(at - Vector2(0, _cell_size * 0.2), _catalog.get_mob(id).death_color)
	if mob.kill_reward > 0:
		_add_text(at, "+%d" % mob.kill_reward, _style.gold_text_color)
	sound_requested.emit(&"death")


## Реакция — значок-вспышка обеих стихий без надписи (docs/37 RX-7): не больше одной на врага
## за 0,8 с; названия — в подсказках и легенде «?».
func _show_reaction(effect_id: StringName, mob: MobState) -> bool:
	for rule: ReactionData in _field.config.reactions:
		if rule.id != effect_id:
			continue
		if _time < _mob_flash_next.get(mob.id, 0.0):
			return true
		_mob_flash_next[mob.id] = _time + MOB_FLASH_SECONDS
		if _flashes.size() >= 24:
			_flashes.pop_front()
		_flashes.append(ReactionFlash.new(rule, _field.get_mob_position(mob)))
		return true
	return false

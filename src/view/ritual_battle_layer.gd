class_name RitualBattleLayer
extends BattleLayer
## Общие PvP-снаряды, реакции, молнии, попадания и исчезновения.
## Полоски оберега и особые статусы опыта рисует RitualBoard.

func _draw_mobs() -> void:
	pass


func _draw_hero_hp(_center: Vector2) -> void:
	pass


func _on_field_mob_killed(mob: MobState) -> void:
	var id: StringName = RitualStage3D.UNIT_IDS.get(mob.data.id, &"basic")
	var at: Vector2 = mob_feet_projector.call(mob)
	_spawn_puff(at - Vector2(0, _cell_size * 0.2), _catalog.get_mob(id).death_color)
	if mob.kill_reward > 0:
		_add_text(at, "+%d" % mob.kill_reward, _style.gold_text_color)
	sound_requested.emit(&"death")

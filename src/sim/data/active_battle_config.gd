class_name ActiveBattleConfig
extends Resource
## Параметры двух приказов основного матча. Время — целые тики.

@export var reserve_deadline_ticks: int = 280
@export var reserve_spawn_interval_ticks: int = 10
@export var bot_release_ticks: int = 180
@export var bot_skill_ticks: int = 120
@export var bot_reaction_ticks: int = 10
@export var bot_reserve_count: int = 3
@export var skills: Array[BattleSkillData] = []


func skill_for(hero_id: StringName) -> BattleSkillData:
	for skill: BattleSkillData in skills:
		if skill.hero_id == hero_id:
			return skill
	return null

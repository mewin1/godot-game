class_name HeroSkillData
extends Resource
## Навык героя: кнопка в панели матча. Стоит золото, не чаще раза за раунд,
## после каждого применения дорожает на cost_step. Что делает — в effect.

enum Timing {
	PREP, ## только в подготовку
	WAVE, ## только в волну
	ANY, ## когда угодно
}

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var timing: Timing = Timing.PREP
@export var cost: int = 5
@export var cost_step: int = 0
@export var effect: HeroEffect


## Цена после uses применений.
func get_cost(uses: int) -> int:
	return cost + cost_step * uses


func get_timing_text() -> String:
	match timing:
		Timing.PREP:
			return "в подготовку"
		Timing.WAVE:
			return "в волну"
	return "в любой момент"

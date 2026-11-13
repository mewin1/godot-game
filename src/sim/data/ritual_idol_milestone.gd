class_name RitualIdolMilestone
extends Resource
## Веха идола (docs/37 IDL-4, решение D7): на rites-м оплаченном заговоре бог даёт идолу
## бесплатный эффект. Эффект — тот же, что у заговоров (RiteData.Effect), числа — заглушки автора.

@export var god: StringName = &""
## Сколько оплаченных заговоров нужно (5 / 10 / 15).
@export var rites: int = 5
@export var title: String = ""
@export_multiline var description: String = ""
@export var effect: RiteData.Effect = RiteData.Effect.DAMAGE
## Величина в единицах поля идола: проценты, цели, тики, тысячные клетки.
@export var value: int = 0


## Эффект в виде заговора — применяется тем же IdolState.apply_rite, без счёта покупки.
func as_rite() -> RiteData:
	var rite: RiteData = RiteData.new()
	rite.id = StringName("milestone_%s_%d" % [god, rites])
	rite.display_name = title
	rite.god = god
	rite.effect = effect
	rite.value = value
	return rite

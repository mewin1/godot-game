class_name StatHeroEffect
extends HeroEffect
## Простая пассивка-число: меняет одно правило игрока или его поля при выборе героя.

enum Kind {
	START_GOLD, ## +value золота сразу
	FREE_REROLLS, ## value бесплатных обновлений витрины в каждом раунде
	SELL_FULL_REFUND, ## продажа всегда возвращает всё вложенное
	SHOP_DISCOUNT, ## повышение магазина на value дешевле
	ARMY_SPEED, ## армия +value% скорости
	ENEMY_ARMY_SLOW, ## чужие армии на своём поле на value% медленнее
	KNOCKBACK, ## моб на середине пути один раз отброшен на value тысячных клетки назад
	EXTRA_OFFERS, ## +value мест на витрине
}

@export var kind: Kind = Kind.START_GOLD
@export var value: int = 0


func on_picked(player: PlayerState) -> void:
	match kind:
		Kind.START_GOLD:
			player.gold += value
		Kind.FREE_REROLLS:
			player.free_rerolls_per_round += value
			player.free_rerolls_left = player.free_rerolls_per_round
		Kind.SELL_FULL_REFUND:
			player.has_full_refund = true
		Kind.SHOP_DISCOUNT:
			player.shop_upgrade_discount += value
		Kind.ARMY_SPEED:
			player.army.speed_percent += value
		Kind.ENEMY_ARMY_SLOW:
			player.field.enemy_army_slow_percent += value
		Kind.KNOCKBACK:
			player.field.knockback_milli += value
		Kind.EXTRA_OFFERS:
			player.shop.extra_offers += value

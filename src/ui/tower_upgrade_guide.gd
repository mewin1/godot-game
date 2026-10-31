class_name TowerUpgradeGuide
extends RefCounted
## Состояние развития и обратная связь переноса; допустимость берётся из симуляции.


## Название уже установленного усиления из каталога заговоров.
static func effect_name(config: GameConfig, effect: int) -> String:
	for rite: RiteData in config.rites:
		if rite.target == RiteData.Target.TOWER and rite.effect == effect:
			return rite.display_name
	return "нет"


## Два слота видны и на поле, и в резерве.
static func slots(config: GameConfig, tower: TowerState) -> String:
	return "Чары: %s · Пробуждение: %s" % [effect_name(config, tower.enchantment),
			effect_name(config, tower.awakening)]


## Ближайшие условия развития без обещания наличия заговора в витрине.
static func next_step(config: GameConfig, player: PlayerState, tower: TowerState) -> String:
	if tower.awakening >= 0:
		return "Пробуждение завершено"
	var missing: PackedStringArray = []
	if tower.level < config.max_tower_level:
		missing.append("слияние до ур.%d" % config.max_tower_level)
	if tower.enchantment < 0:
		missing.append("чары" if player.shop.level >= 2 else "чары из магазина 2")
	if player.shop.level < config.max_shop_level:
		missing.append("магазин %d" % config.max_shop_level)
	return "Для пробуждения: " + ", ".join(missing) if not missing.is_empty() \
			else "Готова к пробуждению: найдите заговор силы или размаха"


## Проверка цели совпадает с покупкой; деньги проверяются до оплаты.
static func rejection(player: PlayerState, rite: RiteData, tower_id: int) -> String:
	if player == null or rite.target != RiteData.Target.TOWER:
		return "Этот заговор — на идол"
	var reason: String = player.check_tower_rite(rite, tower_id)
	if reason != "":
		return reason
	if player.gold < rite.cost:
		return "Не хватает %d зол." % (rite.cost - player.gold)
	return ""

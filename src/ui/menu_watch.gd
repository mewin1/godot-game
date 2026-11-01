extends Control
## Миниатюра двора с тем же светом и опорой, что у построек матча.

const ICE: Texture2D = preload("res://assets/visual_slice/ice.png")
const CANNON: Texture2D = preload("res://assets/visual_slice/cannon.png")
const SCOUT: Texture2D = preload("res://data/visuals/sprites/mob_fast.tres")


## Та же иллюстрация двора и те же контактные тени, что в матче.
func _draw() -> void:
	var extent: Vector2 = size
	if extent.x < extent.y:
		return
	var scale_unit: float = minf(extent.x / 1.78, extent.y)
	PlantedSprite.draw(self, ICE, extent * Vector2(0.73, 0.41),
			Vector2.ONE * scale_unit * 0.245, Color("89caef"))
	PlantedSprite.draw(self, CANNON, extent * Vector2(0.58, 0.55),
			Vector2.ONE * scale_unit * 0.158, Color("c1a37b"))
	var scout_size: Vector2 = Vector2(SCOUT.get_size()) * (scale_unit * 0.095 / SCOUT.get_height())
	PlantedSprite.draw(self, SCOUT, extent * Vector2(0.79, 0.57),
			scout_size, Color("ac9e88"), 0.97)

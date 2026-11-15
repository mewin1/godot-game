extends SceneTree
## Иконки каталога «Городища» (critique_2 п. 28): каждый дом запекается в PNG тем же кодом, что
## ставит его на карту (RitualTownHouse + покраска школы finishes.gdshader), — карточка совпадает
## с домом на улице. Машина на коньке на иконке крупнее (×1,5), чтобы тип читался в 96 px.
## Повторить после правки домов или машин (нужно окно: в headless картинки нет):
## godot --path . --screen 1 -s res://tools/ritual_house_icons.gd
## Затем godot --headless --path . --import, чтобы новые PNG получили .import.

const OUT: String = "res://assets/ritual/town/icons/"
const SIZE: int = 256
const CONFIG: RitualTrialConfig = preload("res://data/ritual/endless.tres")
const STYLE: Arena3DStyle = preload("res://data/visuals/arena_3d_style.tres")
## Вид чуть сбоку и ниже игрового: виден фасад, крыша и машина.
const VIEW: Vector3 = Vector3(-0.6, 0.62, 0.0)
const MACHINE_ZOOM: float = 1.5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world: Node3D = Node3D.new()
	viewport.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.58, 0.63, 0.7)
	environment.environment.ambient_light_energy = 0.75
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation = Vector3(-0.95, 0.9, 0.0)
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.9, 0.76)
	world.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation = Vector3(-0.35, -2.4, 0.0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.62, 0.74, 1.0)
	world.add_child(rim)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation = VIEW
	camera.near = 0.1
	camera.far = 200.0
	world.add_child(camera)
	camera.make_current()
	var made: int = 0
	for data: TowerData in CONFIG.combat.towers:
		if not RitualTownHouse.MACHINES.has(data.id):
			continue
		var tower: RitualTower = RitualTower.new()
		tower.data = data
		tower.level = 1
		var house: RitualTownHouse = RitualTownHouse.new()
		world.add_child(house)
		house.build(tower, STYLE, [Vector3.ZERO])
		house.face(Vector2i.DOWN)
		house._installation.scale *= MACHINE_ZOOM
		for child: Node in house.get_children():
			if child is MultiMeshInstance3D:
				(child as MultiMeshInstance3D).visible = false
		house._process(0.0)  # размер дома на карте (MODEL_SCALE) ставит первый кадр
		_frame(camera, house)
		for frame: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(OUT + String(data.id) + ".png"))
		made += 1
		house.free()
	print("ICONS: ", made, " -> ", OUT)
	quit()


## Ортокамера охватывает дом целиком с небольшим полем.
func _frame(camera: Camera3D, house: Node3D) -> void:
	var inverse: Transform3D = Transform3D(camera.basis, Vector3.ZERO).affine_inverse()
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	for node: Node in house.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		if not part.is_visible_in_tree():
			continue
		var box: AABB = part.global_transform * part.get_aabb()
		for corner: int in 8:
			var local: Vector3 = inverse * box.get_endpoint(corner)
			low = low.min(local)
			high = high.max(local)
	var middle: Vector3 = (low + high) * 0.5
	camera.size = maxf(high.x - low.x, high.y - low.y) * 1.08
	camera.position = camera.basis * Vector3(middle.x, middle.y, high.z + 20.0)

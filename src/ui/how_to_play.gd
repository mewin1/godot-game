extends Control
## Экран «Как играть»: правила кратко. Текст — прямо в сцене scenes/how_to_play.tscn.

@onready var _panel: PanelContainer = %Panel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	ScreenFit.apply(get_window())
	_back_button.pressed.connect(_on_back_button_pressed)
	UiFx.add_press_feedback(_back_button)
	await get_tree().process_frame
	UiFx.pop_in(_panel)



func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		ScreenFit.apply(get_window())


func _on_back_button_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

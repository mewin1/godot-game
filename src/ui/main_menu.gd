extends Control
## Главное меню: Играть / Как играть / Выход и выключатель звука.
## Раскладка — в сцене scenes/main_menu.tscn (её удобно править в редакторе).

const SOUND_ON_ICON: Texture2D = preload("res://assets/ui/icon_sound_on.svg")
const SOUND_OFF_ICON: Texture2D = preload("res://assets/ui/icon_sound_off.svg")

@onready var _sound_bank: SoundBank = $SoundBank

@onready var _menu: VBoxContainer = %Menu
@onready var _play_button: Button = %PlayButton
@onready var _how_to_button: Button = %HowToButton
@onready var _heroes_button: Button = %HeroesButton
@onready var _lab_button: Button = %ReactionLabButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _quit_button: Button = %QuitButton
@onready var _sound_button: Button = %SoundButton


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = DuskTheme.create()
	var background: TextureRect = $Background
	var backdrop: ShaderMaterial = ShaderMaterial.new()
	backdrop.shader = preload("res://assets/shaders/menu_watch.gdshader")
	background.material = backdrop
	_play_button.pressed.connect(_on_play_button_pressed)
	_how_to_button.pressed.connect(_on_how_to_button_pressed)
	_heroes_button.pressed.connect(_on_heroes_button_pressed)
	_lab_button.pressed.connect(_on_lab_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_sound_button.pressed.connect(_on_sound_button_pressed)
	_add_button(%Teams as HBoxContainer, "3 на 3", _on_team3_pressed)
	_add_button(%Teams as HBoxContainer, "2 на 2 на 2", _on_team2_pressed)
	_add_button(%Library as GridContainer, "Настройки", _on_settings_pressed)
	_add_button(%Library as GridContainer, "Проба графики 2.5D", _on_visual_slice_pressed)
	for button: Button in [_play_button, _how_to_button, _heroes_button, _lab_button,
			_sandbox_button, _quit_button, _sound_button]:
		UiFx.add_press_feedback(button)
	_update_sound_icon()
	_menu.modulate.a = 0.0
	await get_tree().process_frame
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)


func _add_button(parent: Container, title: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	UiFx.add_press_feedback(button)


func _update_sound_icon() -> void:
	_sound_button.icon = SOUND_OFF_ICON if SoundBank.is_muted() else SOUND_ON_ICON



func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		ScreenFit.apply(get_window())


func _on_play_button_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.requested_teams = 0
	ScenePaths.go_to(get_tree(), ScenePaths.MATCH)


func _on_how_to_button_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.go_to(get_tree(), ScenePaths.HOW_TO_PLAY)


func _on_heroes_button_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.go_to(get_tree(), ScenePaths.HEROES)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_sound_button_pressed() -> void:
	SoundBank.set_muted(not SoundBank.is_muted())
	_update_sound_icon()
	_sound_bank.play(&"click")


func _on_settings_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.go_to(get_tree(), ScenePaths.SETTINGS)


func _on_team3_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.requested_teams = 2
	ScenePaths.go_to(get_tree(), ScenePaths.MATCH)


func _on_team2_pressed() -> void:
	_sound_bank.play(&"click")
	ScenePaths.requested_teams = 3
	ScenePaths.go_to(get_tree(), ScenePaths.MATCH)


func _on_lab_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.REACTION_LAB)


func _on_sandbox_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.COMBAT_SANDBOX)


func _on_visual_slice_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.VISUAL_SLICE)

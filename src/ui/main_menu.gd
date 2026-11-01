extends Control
## Главное меню: Играть / Как играть / Выход и выключатель звука.
## Раскладка — в сцене scenes/main_menu.tscn (её удобно править в редакторе).

const SOUND_ON_ICON: Texture2D = preload("res://assets/ui/icon_sound_on.svg")
const SOUND_OFF_ICON: Texture2D = preload("res://assets/ui/icon_sound_off.svg")

var _sound_bank: SoundBank

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
	background.texture = CourtyardPainter.ENVIRONMENT
	_sound_bank = SoundBank.new()
	add_child(_sound_bank)
	_play_button.pressed.connect(_on_play_button_pressed)
	_how_to_button.pressed.connect(_on_how_to_button_pressed)
	_heroes_button.pressed.connect(_on_heroes_button_pressed)
	_lab_button.pressed.connect(_on_lab_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_sound_button.pressed.connect(_on_sound_button_pressed)
	var settings_button: Button = Button.new()
	settings_button.text = "Настройки"
	settings_button.pressed.connect(_on_settings_pressed)
	_menu.add_child(settings_button)
	UiFx.add_press_feedback(settings_button)
	for button: Button in [_play_button, _how_to_button, _heroes_button, _lab_button, _quit_button,
			_sound_button]:
		UiFx.add_press_feedback(button)
	_update_sound_icon()
	var visual_button: Button = Button.new()
	visual_button.text = "Проба графики 2.5D"
	visual_button.position = Vector2(24, 24)
	visual_button.size = Vector2(270, 52)
	visual_button.pressed.connect(_on_visual_slice_pressed)
	add_child(visual_button)
	# Ждём кадр: контейнер должен посчитать размеры, иначе «пружинка» крутится вокруг угла.
	await get_tree().process_frame
	var delay: float = 0.0
	for child: Node in _menu.get_children():
		UiFx.pop_in(child as Control, delay)
		delay += 0.07


func _update_sound_icon() -> void:
	_sound_button.icon = SOUND_OFF_ICON if SoundBank.is_muted() else SOUND_ON_ICON



func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		ScreenFit.apply(get_window())


func _on_play_button_pressed() -> void:
	_sound_bank.play(&"click")
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


func _on_lab_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.REACTION_LAB)


func _on_sandbox_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.COMBAT_SANDBOX)


func _on_visual_slice_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.VISUAL_SLICE)

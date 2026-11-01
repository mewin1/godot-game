extends Control
## Экран настроек: звук, громкость, полноэкранный режим. Раскладка строится кодом,
## чтобы не зависеть от правок сцены в редакторе.

var _sound_bank: SoundBank
var _sound_button: Button
var _volume_label: Label
var _fullscreen_button: Button


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = DuskTheme.create()
	_sound_bank = SoundBank.new()
	add_child(_sound_bank)
	_build_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		ScreenFit.apply(get_window())


func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = CourtyardPainter.ENVIRONMENT
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title: Label = Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_sound_button = Button.new()
	_sound_button.pressed.connect(_toggle_sound)
	box.add_child(_sound_button)

	_volume_label = Label.new()
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_volume_label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = SoundBank.get_volume()
	slider.value_changed.connect(_on_volume_changed)
	box.add_child(slider)

	_fullscreen_button = Button.new()
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	box.add_child(_fullscreen_button)

	var back: Button = Button.new()
	back.text = "Назад"
	back.pressed.connect(_go_back)
	box.add_child(back)

	_refresh_labels()
	for button: Button in [_sound_button, _fullscreen_button, back]:
		UiFx.add_press_feedback(button)


func _toggle_sound() -> void:
	SoundBank.set_muted(not SoundBank.is_muted())
	_refresh_labels()
	_sound_bank.play(&"click")


func _on_volume_changed(value: float) -> void:
	SoundBank.set_volume(int(value))
	_refresh_labels()


func _toggle_fullscreen() -> void:
	ScreenFit.set_fullscreen(get_window(), not ScreenFit.is_fullscreen(get_window()))
	_refresh_labels()


func _go_back() -> void:
	_sound_bank.play(&"click")
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


func _refresh_labels() -> void:
	_sound_button.text = "Звук: выключен" if SoundBank.is_muted() else "Звук: включён"
	_volume_label.text = "Громкость: %d%%" % SoundBank.get_volume()
	_fullscreen_button.text = "Режим окна" if ScreenFit.is_fullscreen(get_window()) \
			else "Полный экран"

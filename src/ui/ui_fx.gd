class_name UiFx
extends RefCounted
## Маленькие анимации интерфейса: «пружинка» кнопок, появление, баннеры.

const PRESS_SCALE: float = 0.94
const PRESS_SECONDS: float = 0.08
const BANNER_IN_SECONDS: float = 0.35
const BANNER_HOLD_SECONDS: float = 1.1
const BANNER_OUT_SECONDS: float = 0.4
const BANNER_COLOR: Color = Color(1, 0.88, 0.62)


## Кнопка при нажатии слегка сжимается, при отпускании пружинит обратно.
static func add_press_feedback(button: BaseButton) -> void:
	button.button_down.connect(_scale_to.bind(button, PRESS_SCALE, Tween.TRANS_QUAD))
	button.button_up.connect(_scale_to.bind(button, 1.0, Tween.TRANS_BACK))


## Плавное появление: прозрачность и небольшой «подъём» масштаба.
static func pop_in(control: Control, delay: float = 0.0) -> void:
	control.pivot_offset = control.size * 0.5
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * 0.9
	var tween: Tween = control.create_tween().set_parallel()
	tween.set_ignore_time_scale()
	tween.tween_property(control, "modulate:a", 1.0, 0.3).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Крупная надпись по центру parent: выпрыгивает, висит и тает. Сама удаляется.
## Возвращает баннер — чтобы следующий мог убрать предыдущий и они не накладывались.
static func show_banner(parent: Control, text: String, color: Color = BANNER_COLOR,
		subtitle: String = "") -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label: Label = Label.new()
	label.theme_type_variation = &"BannerLabel"
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	if subtitle != "":
		var sub_label: Label = Label.new()
		sub_label.theme_type_variation = &"HeaderLabel"
		sub_label.text = subtitle
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub_label)
	parent.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.pivot_offset = parent.size * 0.5
	box.scale = Vector2.ONE * 0.6
	box.modulate.a = 0.0
	var tween: Tween = box.create_tween()
	tween.set_ignore_time_scale()
	tween.set_parallel()
	tween.tween_property(box, "scale", Vector2.ONE, BANNER_IN_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "modulate:a", 1.0, BANNER_IN_SECONDS * 0.6)
	tween.chain().tween_property(box, "modulate:a", 0.0, BANNER_OUT_SECONDS) \
			.set_delay(BANNER_HOLD_SECONDS)
	tween.chain().tween_callback(box.queue_free)
	return box


static func _scale_to(button: BaseButton, target: float, transition: Tween.TransitionType) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.set_ignore_time_scale()
	tween.tween_property(button, "scale", Vector2.ONE * target, PRESS_SECONDS * 1.5) \
			.set_trans(transition).set_ease(Tween.EASE_OUT)

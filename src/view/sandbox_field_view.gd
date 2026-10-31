class_name SandboxFieldView
extends FieldView
## Переносы песочницы создают её команды, без команд покупки и состояния матча.

signal sandbox_command_requested(command: SandboxCommand)


func _find_merge_target(_payload: DragPayload, _cell: Vector2i) -> TowerState:
	return null


func _drop_data(at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	_update_hover(payload, at_position)
	if not _hover_valid:
		return
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER \
			if payload.kind == DragPayload.Kind.OFFER else SandboxCommand.Action.MOVE)
	command.tower = payload.data
	command.tower_id = payload.tower_id
	command.cell = _hover_anchor
	command.rotation = payload.rotation
	_hover = null
	_hover_merge_target = null
	sandbox_command_requested.emit(command)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		var tower: TowerState = field.get_tower_at(_cell_at(button.position))
		if tower != null:
			var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.ROTATE)
			command.tower_id = tower.id
			sandbox_command_requested.emit(command)
		accept_event()
		return
	super._gui_input(event)

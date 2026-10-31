class_name MatchEndPanel
extends PanelContainer
## Итог матча: заголовок (победа или место), таблица мест 1–5 и кнопки «Ещё раз» / «В меню».
## Раскладка — в сцене scenes/match_end_panel.tscn.

signal again_pressed()
signal menu_pressed()
signal report_pressed()

const COLOR_HUMAN: Color = Color(0.95, 0.75, 0.42)
const COLOR_HEADER: Color = Color(0.73, 0.67, 0.56)

@onready var _header: Label = %Header
@onready var _table: GridContainer = %Table
@onready var _again_button: Button = %AgainButton
@onready var _menu_button: Button = %MenuButton
@onready var _report_button: Button = %ReportButton


func _ready() -> void:
	_again_button.pressed.connect(func() -> void: again_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_report_button.pressed.connect(func() -> void: report_pressed.emit())
	UiFx.add_press_feedback(_again_button)
	UiFx.add_press_feedback(_menu_button)


## Заполняет таблицу. Ещё живые игроки (если вы выбыли раньше) — вверху, без места.
## elimination_rounds: индекс игрока → раунд, в котором он выбыл.
func show_results(players: Array[PlayerState], human_index: int,
		elimination_rounds: Dictionary[int, int]) -> void:
	var me: PlayerState = players[human_index]
	_header.text = "Победа!" if me.place == 1 else "Вы — %d-е место" % me.place
	for child: Node in _table.get_children():
		child.queue_free()
	for title: String in ["Место", "Игрок", "Выбыл"]:
		_add_cell(title, COLOR_HEADER)
	var ranked: Array[PlayerState] = players.duplicate()
	ranked.sort_custom(_is_ranked_higher)
	for player: PlayerState in ranked:
		var color: Color = COLOR_HUMAN if player.index == human_index else Color.WHITE
		_add_cell(str(player.place) if player.place > 0 else "в игре", color)
		_add_cell("Вы" if player.index == human_index else player.display_name, color)
		var fallen: String = "—"
		if elimination_rounds.has(player.index):
			fallen = "в раунде %d" % elimination_rounds[player.index]
		elif player.place == 1:
			fallen = "устоял ♥%d" % maxi(0, player.hero_hp)
		_add_cell(fallen, color)


func _add_cell(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	_table.add_child(label)


## Сначала ещё играющие (место 0), потом по месту.
func _is_ranked_higher(a: PlayerState, b: PlayerState) -> bool:
	if (a.place == 0) != (b.place == 0):
		return a.place == 0
	if a.place != b.place:
		return a.place < b.place
	return a.hero_hp > b.hero_hp

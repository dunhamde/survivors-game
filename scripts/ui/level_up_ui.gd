extends CanvasLayer

signal choice_made(choice: Dictionary)

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel
@onready var cards: HBoxContainer = $Center/Panel/Margin/VBox/Cards

var _choices: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_ui()
	for i in cards.get_child_count():
		var button := cards.get_child(i) as Button
		button.pressed.connect(_on_card_pressed.bind(i))


func show_choices(choices: Array[Dictionary]) -> void:
	_choices = choices
	visible = true
	for i in cards.get_child_count():
		var button := cards.get_child(i) as Button
		var choice: Dictionary = choices[i] if i < choices.size() else {}
		button.get_node("VBox/Title").text = str(choice.get("title", ""))
		button.get_node("VBox/Desc").text = str(choice.get("desc", ""))
		button.visible = i < choices.size()
	if cards.get_child_count() > 0:
		(cards.get_child(0) as Button).grab_focus()


func hide_ui() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_pick(0)
			KEY_2:
				_pick(1)
			KEY_3:
				_pick(2)


func _on_card_pressed(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	if not visible or index < 0 or index >= _choices.size():
		return
	choice_made.emit(_choices[index])

extends Control
class_name ValueBar

@export var label_text: String = ""
@export var max_value: float = 100.0
@export var current_value: float = 100.0

@export var progress_bar: ProgressBar
@export var name_label: Label
@export var value_label: Label

var _current_value: float = 100.0
var _max_value: float = 100.0

func _ready():
	# Если элементы не назначены через @export, пытаемся найти их автоматически
	if not progress_bar:
		progress_bar = get_node_or_null("ProgressBar") as ProgressBar
	if not name_label:
		name_label = get_node_or_null("NameLabel") as Label
	if not value_label:
		value_label = get_node_or_null("ValueLabel") as Label
	
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
	
	if name_label and label_text != "":
		name_label.text = label_text
	
	_update_value_display()

func set_max_value(max: float):
	_max_value = max
	max_value = max
	if progress_bar:
		progress_bar.max_value = max
	_update_value_display()

func set_current_value(current: float):
	_current_value = clamp(current, 0, _max_value)
	current_value = _current_value
	if progress_bar:
		progress_bar.value = _current_value
	_update_value_display()

func set_value(current: float, max: float):
	set_max_value(max)
	set_current_value(current)

func _update_value_display():
	if value_label:
		var current_int = int(_current_value)
		var max_int = int(_max_value)
		value_label.text = str(current_int) + " / " + str(max_int)


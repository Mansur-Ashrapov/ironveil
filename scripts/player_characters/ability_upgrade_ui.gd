extends Control
class_name AbilityUpgradeUI

signal ability_selected(ability_idx: int)

@export var abilities_container: VBoxContainer
@export var title_label: Label

var ability_button_scene: PackedScene = null

func _ready() -> void:
	hide()

func show_upgrade_selection(abilities: Array):
	# Очищаем предыдущие кнопки
	for child in abilities_container.get_children():
		child.queue_free()
	
	# Создаём кнопки для каждого навыка, который можно прокачать
	var has_upgradable = false
	for idx in range(abilities.size()):
		var ability = abilities[idx] as Ability
		if ability.can_upgrade():
			has_upgradable = true
			var button = _create_ability_button(ability, idx)
			abilities_container.add_child(button)
	
	if has_upgradable:
		title_label.text = "УРОВЕНЬ ПОВЫШЕН! Выберите способность для улучшения:"
		show()
	else:
		# Все навыки на максимальном уровне
		hide()

func _create_ability_button(ability: Ability, idx: int) -> Button:
	var button = Button.new()
	
	# Заголовок с названием и уровнем
	var text = "%s [Ур.%d -> %d]\n" % [ability.ability_name, ability.ability_level, ability.ability_level + 1]
	
	# Описание улучшений словами
	text += ability.get_upgrade_description() + "\n"
	
	button.text = text
	button.custom_minimum_size = Vector2(400, 80)
	button.pressed.connect(_on_ability_button_pressed.bind(idx))
	
	# Стиль кнопки
	button.add_theme_font_size_override("font_size", 14)
	
	return button

func _on_ability_button_pressed(ability_idx: int):
	# Проигрываем звук улучшения
	SoundManager.play_sound("ui_upgrade")
	ability_selected.emit(ability_idx)
	hide()


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
	
	var current_cd = ability.get_effective_cooldown()
	var next_cd = ability.cooldown * max(1.0 - ((ability.ability_level + 1) * Ability.COOLDOWN_REDUCTION_PER_LEVEL), 0.3)
	
	var current_mana = ability.get_effective_mana_cost()
	var next_mana = ability.mana_cost * max(1.0 - ((ability.ability_level + 1) * Ability.COST_REDUCTION_PER_LEVEL), 0.4)
	
	var current_stamina = ability.get_effective_stamina_cost()
	var next_stamina = ability.stamina_cost * max(1.0 - ((ability.ability_level + 1) * Ability.COST_REDUCTION_PER_LEVEL), 0.4)
	
	var text = "%s [Ур.%d -> %d]\n" % [ability.ability_name, ability.ability_level, ability.ability_level + 1]
	text += "КД: %.1f -> %.1f  " % [current_cd, next_cd]
	
	if ability.mana_cost > 0:
		text += "МН: %.0f -> %.0f  " % [current_mana, next_mana]
	if ability.stamina_cost > 0:
		text += "ВЫН: %.0f -> %.0f" % [current_stamina, next_stamina]
	
	button.text = text
	button.custom_minimum_size = Vector2(400, 60)
	button.pressed.connect(_on_ability_button_pressed.bind(idx))
	
	# Стиль кнопки
	button.add_theme_font_size_override("font_size", 16)
	
	return button

func _on_ability_button_pressed(ability_idx: int):
	# Проигрываем звук улучшения
	SoundManager.play_sound("ui_upgrade")
	ability_selected.emit(ability_idx)
	hide()


extends CanvasLayer

@export var hp: Label
@export var st: Label
@export var mp: Label
@export var ep: Label
@export var lvl: Label
@export var ability_upgrade_ui: AbilityUpgradeUI

var player: PlayerBase

func setup(player_ref: PlayerBase):
	player = player_ref
	player.show_ability_upgrade_ui.connect(_on_show_ability_upgrade_ui)
	if ability_upgrade_ui:
		ability_upgrade_ui.ability_selected.connect(_on_ability_selected)

func _on_show_ability_upgrade_ui(abilities: Array):
	if ability_upgrade_ui:
		ability_upgrade_ui.show_upgrade_selection(abilities)

func _on_ability_selected(ability_idx: int):
	if player:
		player.request_upgrade_ability(ability_idx)

func new_parameters(new_health: int, new_mana: int, new_stamina: int, new_experience: int, new_lvl: int):
	hp.text = "ЗД: " + str(new_health)
	st.text = "ВЫН: " + str(new_stamina)
	mp.text = "МН: " + str(new_mana)
	ep.text = "ОПЫТ: " + str(new_experience)
	lvl.text = "УР: " + str(new_lvl)

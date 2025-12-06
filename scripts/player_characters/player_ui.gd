extends CanvasLayer

@export var hp: Label
@export var st: Label
@export var mp: Label
@export var ep: Label
@export var lvl: Label
@export var ability_upgrade_ui: AbilityUpgradeUI
@export var respawn_timer_label: Label

var player: PlayerBase

func setup(player_ref: PlayerBase):
	player = player_ref
	player.show_ability_upgrade_ui.connect(_on_show_ability_upgrade_ui)
	player.respawn_timer_updated.connect(_on_respawn_timer_updated)
	player.respawn_timer_started.connect(_on_respawn_timer_started)
	player.respawn_timer_finished.connect(_on_respawn_timer_finished)
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

func _on_respawn_timer_started():
	if respawn_timer_label:
		respawn_timer_label.visible = true

func _on_respawn_timer_updated(time_remaining: float):
	if respawn_timer_label:
		var seconds = int(ceil(time_remaining))
		respawn_timer_label.text = "Возрождение через: " + str(seconds)

func _on_respawn_timer_finished():
	if respawn_timer_label:
		respawn_timer_label.visible = false

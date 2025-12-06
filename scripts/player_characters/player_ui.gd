extends CanvasLayer

@export var hp_bar: ValueBar
@export var stamina_bar: ValueBar
@export var mana_bar: ValueBar
@export var experience_bar: ValueBar
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
	
	# Инициализируем максимумы из игрока
	if player and hp_bar:
		hp_bar.set_max_value(player.max_health)
	if player and stamina_bar:
		stamina_bar.set_max_value(player.max_stamina)
	if player and mana_bar:
		mana_bar.set_max_value(player.max_mana)
	if player and experience_bar:
		experience_bar.set_max_value(player.experience_to_level_up)

func _on_show_ability_upgrade_ui(abilities: Array):
	if ability_upgrade_ui:
		ability_upgrade_ui.show_upgrade_selection(abilities)

func _on_ability_selected(ability_idx: int):
	if player:
		player.request_upgrade_ability(ability_idx)

func new_parameters(new_health: int, new_mana: int, new_stamina: int, new_experience: int, _new_lvl: int):
	if hp_bar:
		hp_bar.set_current_value(new_health)
		# Обновляем максимум, если он изменился (при повышении уровня)
		if player and hp_bar.max_value != player.max_health:
			hp_bar.set_max_value(player.max_health)
	
	if stamina_bar:
		stamina_bar.set_current_value(new_stamina)
		if player and stamina_bar.max_value != player.max_stamina:
			stamina_bar.set_max_value(player.max_stamina)
	
	if mana_bar:
		mana_bar.set_current_value(new_mana)
		if player and mana_bar.max_value != player.max_mana:
			mana_bar.set_max_value(player.max_mana)
	
	if experience_bar:
		experience_bar.set_current_value(new_experience)
		if player and experience_bar.max_value != player.experience_to_level_up:
			experience_bar.set_max_value(player.experience_to_level_up)

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

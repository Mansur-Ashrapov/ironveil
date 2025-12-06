extends Ability
class_name FireballAbility

var fireball_scene: PackedScene = preload("res://scenes/fireball.tscn")

func _init() -> void:
	cooldown = 1.5
	stamina_cost = 5
	mana_cost = 20

const FIREBALL_OFFSET_DISTANCE: float = 50.0

func _on_use(user: PlayerBase):
	var fireball: Fireball = fireball_scene.instantiate()
	fireball.get_ready(user.base_damage)
	user.get_tree().get_first_node_in_group("trash").add_child(fireball)
	
	var ability_data = user.get_ability_direction_and_position(FIREBALL_OFFSET_DISTANCE)
	fireball.direction = ability_data.direction
	fireball.global_position = ability_data.position

extends Ability
class_name SwordAbility

var sword_scene: PackedScene = preload("res://scenes/sword_test.tscn")

func _init() -> void:
	ability_name = "Sword"
	cooldown = 0.7
	stamina_cost = 5
	mana_cost = 0

const SWORD_OFFSET_DISTANCE: float = 80.0

func _on_use(user: PlayerBase):
	var sword: SwordTest = sword_scene.instantiate()
	sword.get_ready(user.base_damage)
	user.add_child(sword)
	sword.flip_v = user.sprite.flip_h
	
	var ability_data = user.get_ability_direction_and_position(SWORD_OFFSET_DISTANCE)
	sword.impulse_direction = ability_data.direction
	sword.global_position = ability_data.position
	sword.rotation = ability_data.direction.angle()

extends Ability
class_name FireballAbility

var fireball_scene: PackedScene = preload("res://scenes/fireball.tscn")

func _init() -> void:
	cooldown = 1.5
	stamina_cost = 5
	mana_cost = 20

func _on_use(user: PlayerBase):
	var fireball: Fireball = fireball_scene.instantiate()
	fireball.get_ready(user.base_damage)
	user.get_tree().get_first_node_in_group("trash").add_child(fireball)
	if user.direction != Vector2.ZERO:
		fireball.direction = user.direction
		fireball.global_position = user.global_position + user.direction * Vector2(50.0, 50.0)
	elif user.sprite.flip_h:
		fireball.direction = Vector2.LEFT
		fireball.global_position = user.global_position + Vector2.RIGHT * Vector2(50.0, 50.0)
	else:
		fireball.direction = Vector2.RIGHT
		fireball.global_position = user.global_position + Vector2.LEFT * Vector2(50.0, 50.0)

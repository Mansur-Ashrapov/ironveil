extends Ability
class_name Sword

var sword_scene: PackedScene = preload("res://scenes/sword_test.tscn")

func _init() -> void:
	cooldown = 0.7
	stamina_cost = 5
	mana_cost = 0

func _on_use(user: PlayerBase):
	var sword: SwordTest = sword_scene.instantiate()
	sword.get_ready(user.base_damage)
	user.add_child(sword)
	sword.flip_h = user.sprite.flip_h
	sword.impulse_direction = user.direction
	if user.direction != Vector2.ZERO:
		sword.global_position = user.global_position + user.direction * Vector2(80.0, 80.0)
		sword.rotation = user.direction.angle() + 135 if sword.flip_h else user.direction.angle()
	elif not sword.flip_h:
		sword.global_position = user.global_position + Vector2.RIGHT * Vector2(80.0, 80.0)
	else:
		sword.global_position = user.global_position + Vector2.LEFT * Vector2(80.0, 80.0)

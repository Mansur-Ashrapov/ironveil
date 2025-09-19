extends Ability
class_name Sword

var sword_scene: PackedScene = preload("res://scenes/sword_test.tscn")

func _on_use(user: PlayerBase):
	var sword: Sprite2D = sword_scene.instantiate()
	user.add_child(sword)
	sword.flip_h = user.sprite.flip_h
	if user.direction != Vector2.ZERO:
		sword.global_position = user.global_position + user.direction * Vector2(50.0, 50.0)
	elif not sword.flip_h:
		sword.global_position = user.global_position + Vector2.RIGHT * Vector2(50.0, 50.0)
	else:
		sword.global_position = user.global_position + Vector2.LEFT * Vector2(50.0, 50.0)

extends AnimationController
class_name PlayerAnimationController

func _ready() -> void:
	animation_finished.connect(_play_idle)

func _play_idle(anim_name: String):
	if anim_name.contains("ability"):
		play_loop("idle")

func on_get_hit():
	print_debug("played ", "get_hit")
	play_once("get_hit")

func on_direction_changed(dir: Vector2):
	print_debug("played ", dir)
	if dir == Vector2.ZERO:
		play_loop("idle")
	else:
		play_loop("moving")

func on_ability_used(ability_name: String):
	print_debug("played ", ability_name)
	play_once(ability_name)

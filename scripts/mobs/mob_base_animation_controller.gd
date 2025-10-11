extends AnimationController
class_name MobBaseAnimationController


func _ready() -> void:
	animation_finished.connect(change_to_idle)

func change_to_idle(_anim_name: String):
	play_loop("idle")

func on_get_hit():
	play_once("damage")

func moving_to_player():
	play_loop("walk")

func stop_moving():
	play_loop("idle")

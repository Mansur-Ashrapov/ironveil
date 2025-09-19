extends AnimationPlayer
class_name AnimationController

@export var blend_time: float = 0.1

func _ready() -> void:
	play_loop("idle")

func play_loop(anim_name: String) -> void:
	if self.has_animation(anim_name):
		if anim_name != current_animation:
			stop()
		var anim = self.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_LINEAR
		self.play(anim_name, blend_time)

func play_once(anim_name: String):
	if self.has_animation(anim_name):
		stop()
		var anim = self.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_NONE
		self.play(anim_name, blend_time)

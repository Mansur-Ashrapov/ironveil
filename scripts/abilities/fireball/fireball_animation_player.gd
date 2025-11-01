extends AnimationController

func _ready() -> void:
	current_animation = "mowing"


func explosion():
	current_animation = "explosion"

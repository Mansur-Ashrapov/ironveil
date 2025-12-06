extends Ability
class_name BeamAbility

var beam_scene: PackedScene = preload("res://scenes/beam.tscn")

func _init() -> void:
	ability_name = "Beam"
	cooldown = 2.5
	stamina_cost = 10
	mana_cost = 25

const BEAM_OFFSET_DISTANCE: float = 60.0

func use(user: PlayerBase):
	last_used_time = Time.get_ticks_msec() / 1000.0
	_on_use(user)

func _on_use(user: PlayerBase):
	var beam: Beam = beam_scene.instantiate()
	beam.get_ready(user.base_damage * 2.0)  # Луч наносит двойной урон
	beam.user = user
	user.get_tree().get_first_node_in_group("trash").add_child(beam)
	
	var ability_data = user.get_ability_direction_and_position(BEAM_OFFSET_DISTANCE)
	beam.direction = ability_data.direction
	beam.global_position = ability_data.position


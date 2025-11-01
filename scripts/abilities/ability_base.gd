extends Resource
class_name Ability

@export var cooldown: float = 0.7
@export var stamina_cost: float = 5.0
@export var mana_cost: float = 5.0

var last_used_time: float = -999.0

func can_use(mana: float, stamina: float) -> bool:
	var stamina_remains = stamina - stamina_cost
	var mana_remains = mana - mana_cost
	return Time.get_ticks_msec() / 1000.0 - last_used_time >= cooldown and stamina_remains >= 0 and mana_remains >= 0

func use(user: PlayerBase):
	last_used_time = Time.get_ticks_msec() / 1000.0
	_on_use(user)

func _on_use(_user: PlayerBase):
	# Переопределяется в наследниках
	pass

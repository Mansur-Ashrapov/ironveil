extends Control

@export var hp: Label
@export var st: Label
@export var mp: Label
@export var ep: Label
@export var lvl: Label

func new_parametrs(new_health: int, new_mana: int, new_stamina: int, new_experience: int, new_lvl: int):
	hp.text = "HP: " + str(new_health)
	st.text = "ST: " + str(new_mana)
	mp.text = "MP: " + str(new_stamina)
	ep.text = "EXP: " + str(new_experience)
	lvl.text = "LVL: " + str(new_lvl)

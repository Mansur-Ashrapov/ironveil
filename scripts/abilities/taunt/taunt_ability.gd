extends Ability
class_name TauntAbility

var taunt_effect_scene: PackedScene = preload("res://scenes/taunt_effect.tscn")

@export var taunt_radius: float = 500.0
@export var taunt_duration: float = 5.0
@export var resistance_bonus: float = 0.2  # 20% дополнительного сопротивления урону

func _init() -> void:
	ability_name = "Taunt"
	cooldown = 10.0
	stamina_cost = 15.0
	mana_cost = 10.0

func get_upgrade_description() -> String:
	return "• Быстрее перезарядка\n• Меньше расход маны и выносливости"

func _on_use(user: PlayerBase):
	# Визуальный эффект - показываем на всех клиентах
	_spawn_visual_effect(user)
	
	# Логика taunt - только на сервере
	if not user.get_tree().get_multiplayer().is_server():
		return
	
	# Применяем бонус к сопротивлению урону
	_apply_damage_resistance(user)
	
	# Находим всех мобов в радиусе
	var mobs = user.get_tree().get_nodes_in_group("mob")
	
	var taunted_count = 0
	
	for mob in mobs:
		if not mob or not mob.is_inside_tree():
			continue
		
		if not mob is MobBase:
			continue
		
		var distance = user.global_position.distance_to(mob.global_position)
		
		if distance <= taunt_radius:
			(mob as MobBase).force_aggro(user, taunt_duration)
			taunted_count += 1
	
	print("TAUNT RESULT: ", taunted_count, " mobs taunted")

func _apply_damage_resistance(user: PlayerBase):
	var original_resistance = user.damage_rezistance
	user.damage_rezistance = clampf(user.damage_rezistance + resistance_bonus, 0.0, 1.0)
	
	# Создаём таймер для снятия бонуса
	var timer = user.get_tree().create_timer(taunt_duration)
	timer.timeout.connect(func():
		if is_instance_valid(user):
			user.damage_rezistance = original_resistance
	)

func _spawn_visual_effect(user: PlayerBase):
	var effect: TauntEffect = taunt_effect_scene.instantiate()
	effect.setup(taunt_radius)
	user.get_tree().get_first_node_in_group("trash").add_child(effect)
	effect.global_position = user.global_position

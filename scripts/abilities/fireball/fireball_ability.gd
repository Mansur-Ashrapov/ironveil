extends Ability
class_name FireballAbility

var fireball_scene: PackedScene = preload("res://scenes/fireball.tscn")

func _init() -> void:
	ability_name = "Fireball"
	cooldown = 1.5
	stamina_cost = 5
	mana_cost = 20

const FIREBALL_OFFSET_DISTANCE: float = 50.0

func get_upgrade_description() -> String:
	return "• Быстрее перезарядка\n• Меньше расход маны"

func _on_use(user: PlayerBase):
	# Создаём fireball только на сервере - MultiplayerSpawner синхронизирует на клиенты
	if not user.get_tree().get_multiplayer().is_server():
		return
	
	var ability_data = user.get_ability_direction_and_position(FIREBALL_OFFSET_DISTANCE)
	
	var fireball: Fireball = fireball_scene.instantiate()
	fireball.get_ready(user.base_damage)
	# Устанавливаем свойства ДО добавления в дерево для корректной репликации
	# Используем position вместо global_position (TRASH в позиции 0,0)
	fireball.direction = ability_data.direction
	fireball.position = ability_data.position
	
	# true для генерации уникального имени, необходимо для MultiplayerSpawner
	user.get_tree().get_first_node_in_group("trash").add_child(fireball, true)

extends CharacterBody2D
class_name MobBase


@export var expirience_cost: int = 30
@export var health: int = 30
@onready var animation_cotroller: MobBaseAnimationController = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

const SPEED = 60
const MAX_DISTANCE = 500
# Кадры между обновлением цели
const TARGET_UPDATE_INTERVAL = 30
# Радиус агрессии
const AGRO_RADIUS = 300

var target_player: Node2D
var last_target_update = 0

signal get_hit()
signal moving_to_player()
signal stop_moving()

func _ready() -> void:
	# Находим ближайщего игрока в сцене
	if multiplayer.is_server():
		find_nearest_player()
	
	get_hit.connect(animation_cotroller.on_get_hit)
	moving_to_player.connect(animation_cotroller.moving_to_player)
	stop_moving.connect(animation_cotroller.stop_moving)
	
func find_nearest_player() -> bool:
	# Ищем игрока по группе или по имени класса
	var players = get_all_players()
	
	if players.size() == 0:
		target_player = null
		return false
		
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		# Определяем цель по дистанции
		if target_player == player and distance <= AGRO_RADIUS:
			nearest_player = player
			break
		elif distance < min_distance and distance <= MAX_DISTANCE:
			min_distance = distance
			nearest_player = player
			
	target_player = nearest_player
	return target_player != null


func get_damage(amount: int):
	health -= amount
	if health <= 0:
		for player in get_all_players():
			if player is PlayerBase:
				player.get_expirience(expirience_cost)
		
		death.rpc()
		
	get_hit.emit()

@rpc("any_peer", "call_local", "reliable")
func death():
	queue_free()

func get_all_players() -> Array:
	var players = []
	
	# Объединяем все возможные источники игроков
	var all_possible_players = []
	all_possible_players.append_array(get_tree().get_nodes_in_group("players"))
	
	# Убираем дубликаты
	for player in all_possible_players:
		if player is PlayerBase and not players.has(player):
			players.append(player)
	
	return players

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		mob_movement()

func mob_movement():
	# Обновляем цель с итервалом
	last_target_update += 1
	if last_target_update >= TARGET_UPDATE_INTERVAL:
		find_nearest_player()
		last_target_update = 0
	
	if target_player == null:
		if not find_nearest_player():
			velocity = Vector2.ZERO
			stop_moving.emit()
			return
	
	# Проверяем валидность текущей цели
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion():
		target_player = null
		return
	
	var distance_to_target = global_position.distance_to(target_player.global_position)
	
	# Если игрок слишком далеко, не преследовать
	if distance_to_target > MAX_DISTANCE:
		find_nearest_player()
		if target_player == null:
			velocity = Vector2.ZERO
			stop_moving.emit()
			return

	# Вычисляем направление к игроку
	var direction_to_target = (target_player.global_position - global_position).normalized()

	# Устанавливаем скорость
	velocity = direction_to_target * SPEED

	# Поворачиваем спрайт в сторону игрока
	if abs(direction_to_target.x) > 0.1:
		sprite.flip_h = direction_to_target.x < 0

	# Двигаем моба
	move_and_slide()

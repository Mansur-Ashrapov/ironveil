extends Sprite2D
class_name Fireball

var damage: float = 0
var direction: Vector2 = Vector2(1, 1)

# Параметры самонаводки
var speed: float = 400.0
var homing_radius: float = 600.0
var homing_strength: float = 4.0
@export var target_path: NodePath
var target: Node2D = null
var explosion_radius: float = 130
@export var can_move: bool = true

var explosion_area: Node2D

func _ready() -> void:
	if not multiplayer.is_server():
		return

	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.area_entered.connect(_on_area_2d_area_entered)
	
	# Запускаем таймер на уничтожение, если не столкнётся
	await get_tree().create_timer(10).timeout
	sync_explosion.rpc()

func get_ready(_damage: float):
	damage = _damage

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	# Обновляем цель
	if multiplayer.is_server():
		_update_target()

	# Если есть цель, поворачиваемся и летим к ней
	if has_node(target_path):
		target = get_node(target_path)
	
	if target and is_instance_valid(target):
		var dir_to_target = (target.global_position - global_position).normalized()
		direction = direction.lerp(dir_to_target, delta * homing_strength).normalized()
	
	# Движение фаербола
	global_position += direction * speed * delta

func _update_target() -> void:
	# Если уже есть цель и она жива — не ищем заново
	if target and is_instance_valid(target):
		return
	
	# Ищем ближайшего моба в радиусе самонаводки
	var mobs = get_tree().get_nodes_in_group("mob")
	var nearest_dist = INF
	var nearest = null
	
	for mob in mobs:
		if not mob or not mob.is_inside_tree():
			continue
		var dist = global_position.distance_to(mob.global_position)
		if dist < homing_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = mob
	
	if is_instance_valid(nearest):
		target_path = nearest.get_path()

	
@rpc("any_peer", "call_local", "reliable")
func sync_explosion():
	$AnimationPlayer.explosion()
	await get_tree().create_timer(0.3).timeout
	queue_free()

func explode():
	can_move = false
	# Ищем ближайшего моба в радиусе самонаводки
	var mobs = get_tree().get_nodes_in_group("mob")
	for mob in mobs:
		if not mob or not mob.is_inside_tree():
			continue
		var dist = global_position.distance_to(mob.global_position)
		if dist <= explosion_radius:
			(mob as MobBase).get_damage(damage)

	sync_explosion.rpc()

func _on_body_entered(_body: Node2D):
	if not multiplayer.is_server():
		return
	explode()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server() or not area.is_in_group("obstacles"):
		return
	explode()

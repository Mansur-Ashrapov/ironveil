extends Sprite2D
class_name Fireball

const MAX_LIFETIME: float = 10.0
const EXPLOSION_ANIMATION_DURATION: float = 0.3
const TARGET_UPDATE_INTERVAL: float = 0.2  # Обновляем цель раз в 0.2 секунды вместо каждого кадра

var damage: float = 0
var direction: Vector2 = Vector2(1, 1)

# Параметры самонаводки
var speed: float = 400.0
var homing_radius: float = 600.0
var homing_strength: float = 4.0
var explosion_radius: float = 130
@export var can_move: bool = true

# Упрощённое управление целью - используем прямую ссылку вместо NodePath
var target: Node2D = null
var target_update_timer: float = 0.0

func _ready() -> void:
	if not multiplayer.is_server():
		return

	_setup_area_connections()
	_start_lifetime_timer()

func _setup_area_connections() -> void:
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.area_entered.connect(_on_area_2d_area_entered)

func _start_lifetime_timer() -> void:
	# Запускаем таймер на уничтожение, если не столкнётся
	await get_tree().create_timer(MAX_LIFETIME).timeout
	if _is_valid():
		sync_explosion.rpc()

func get_ready(_damage: float):
	damage = _damage

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	
	# Вся логика движения только на сервере
	if multiplayer.is_server():
		_process_movement(delta)
	
	# Визуальное обновление (поворот спрайта) на всех клиентах
	_update_visual_rotation()

func _process_movement(delta: float) -> void:
	# Обновляем цель с интервалом для оптимизации
	target_update_timer -= delta
	if target_update_timer <= 0.0:
		_update_target()
		target_update_timer = TARGET_UPDATE_INTERVAL
	
	# Обновляем направление к цели, если она есть
	if _is_target_valid():
		var dir_to_target = (target.global_position - global_position).normalized()
		direction = direction.lerp(dir_to_target, delta * homing_strength).normalized()
	
	# Движение фаербола
	global_position += direction * speed * delta

func _update_target() -> void:
	# Если цель ещё валидна, не ищем новую
	if _is_target_valid():
		return
	
	# Ищем ближайшего моба в радиусе самонаводки
	var nearest_mob = _find_nearest_mob()
	if nearest_mob:
		target = nearest_mob

func _find_nearest_mob() -> Node2D:
	var mobs = get_tree().get_nodes_in_group("mob")
	var nearest_dist = INF
	var nearest: Node2D = null
	
	for mob in mobs:
		if not _is_mob_valid(mob):
			continue
		
		var dist = global_position.distance_to(mob.global_position)
		if dist < homing_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = mob
	
	return nearest

func _update_visual_rotation() -> void:
	# Поворачиваем спрайт в направлении движения
	if direction.length_squared() > 0.01:
		rotation = direction.angle()

func _is_target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()

func _is_mob_valid(mob: Node) -> bool:
	return mob != null and is_instance_valid(mob) and mob.is_inside_tree()

func _is_valid() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()

@rpc("any_peer", "call_local", "reliable")
func sync_explosion():
	if not _is_valid():
		return
	
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player and is_instance_valid(anim_player):
		anim_player.explosion()
	
	await get_tree().create_timer(EXPLOSION_ANIMATION_DURATION).timeout
	
	if _is_valid():
		call_deferred("queue_free")

func explode():
	if not _is_valid():
		return
		
	can_move = false
	
	# Наносим урон всем мобам в радиусе взрыва
	_deal_explosion_damage()
	
	if _is_valid():
		sync_explosion.rpc()

func _deal_explosion_damage() -> void:
	if not multiplayer.is_server():
		return
	
	var mobs = get_tree().get_nodes_in_group("mob")
	for mob in mobs:
		if not _is_mob_valid(mob):
			continue
		
		var dist = global_position.distance_to(mob.global_position)
		if dist <= explosion_radius:
			if mob is MobBase:
				mob.take_damage(damage, global_position)

func _on_body_entered(_body: Node2D):
	if not multiplayer.is_server():
		return
	explode()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server() or not area.is_in_group("obstacles"):
		return
	explode()

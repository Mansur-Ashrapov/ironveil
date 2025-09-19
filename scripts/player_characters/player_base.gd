extends CharacterBody2D
class_name PlayerBase

const SPEED = 300.0
const LERP_SPEED = 20.0

@export var animation_controller: PlayerAnimationController
@export var sprite: Sprite2D
var player_camera: Camera2D

# Ключ абилки, ключ для клавиши и ключ анимации должны совпадать, чтобы все работало
@export var abilities: Array
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var max_mana := 100.0

var abilities_instances: Array

var health := max_health
var stamina := max_stamina
var mana := max_mana

var direction: Vector2 = Vector2(1, 0) # направление движения
var last_direction: Vector2 = Vector2(1, 0) # нужен чтобы не отправлять Vector2.ZERO при отсутсвии инпута и наоборот, если инпут не меняется, сохранять прошлый
var can_move: bool = true # когда персонаж использует абилку, не может двигаться

# SIGNALS
signal parametrs_changed(new_health: float, new_mana: float, new_stamina: float)
signal get_hit()
signal used_ability(ability_name: String)
signal changed_direction(new_diretion: Vector2)

# POSITION INTERPOLATION
var state_buffer := [] # Буффер передвижений игрока


func _ready() -> void:
	get_hit.connect(animation_controller.on_get_hit)
	used_ability.connect(animation_controller.on_ability_used)
	changed_direction.connect(animation_controller.on_direction_changed)
	
	for ability in abilities:
		abilities_instances.append(ability.new())

func _enter_tree() -> void:
	# назначаем игрока владельцем
	set_multiplayer_authority(name.to_int())
	if is_multiplayer_authority():
		player_camera = Camera2D.new()
		self.add_child(player_camera)

	# на сервере получаем тикер и подключаем timeout, по которому обновляется состояние игроков
	if multiplayer.is_server():
		var server_sync: ServerSync = get_tree().get_first_node_in_group("server_sync")
		server_sync.tick_timer.timeout.connect(broadcast_state)

func _process(delta: float) -> void:
	# обработка нажатий игрока и отправка их серверу
	if is_multiplayer_authority() and not multiplayer.is_server():
		_handle_move_input()
		_handle_abilities_input()
	# синхронизация позиций через интерполяцию локально
	if not multiplayer.is_server():
		_interpolate_position()
	elif multiplayer.is_server() and can_move: # Расчет положения игрока на сервере
		global_position += direction * SPEED * delta
	_flip_sprite()
	
func _flip_sprite():
	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

# Получает ввод игрока и отправляет вектор направления передвижения
func _handle_move_input() -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if last_direction == Vector2.ZERO and direction == Vector2.ZERO or last_direction == direction: return
	elif not can_move: 
			update_move_input.rpc_id(1, Vector2.ZERO)
			last_direction = direction
	update_move_input.rpc_id(1, direction)
	changed_direction.emit(direction)
	last_direction = direction

# Обрабатывает использование абилок
func _handle_abilities_input() -> void:
	for idx in range(0, abilities_instances.size()):
		if Input.is_action_just_pressed("ability" + str(idx)):
			if abilities_instances[idx].can_use(mana, stamina):
				server_use_ability.rpc_id(1, idx)

func take_damage(amount: float):
	health -= amount
	get_hit.emit()

	if health <= 0:
		# TODO death
		pass

	sync_parametrs.rpc(health, mana, stamina)

# Сервер обрабатывает использование абилки
@rpc("any_peer", "reliable")
func server_use_ability(ability_idx: int):
	if not multiplayer.is_server(): return
	if abilities_instances.size() > ability_idx and abilities_instances[ability_idx].can_use(mana, stamina):
		abilities_instances[ability_idx].use(self)
		mana -= (abilities_instances[ability_idx] as Ability).mana_cost
		stamina -= (abilities_instances[ability_idx] as Ability).stamina_cost
		sync_parametrs.rpc(health, mana, stamina)
		sync_ability.rpc(ability_idx)
		_stop_moving_while_use_ability(ability_idx)

func _stop_moving_while_use_ability(ability_idx: int):
	can_move = false
	await get_tree().create_timer((abilities_instances[ability_idx] as Ability).timeout_time).timeout
	can_move = true

# Серверная функция которая получает ввод передвижений игрока и высчитывает новое положение
@rpc("any_peer", "unreliable", "call_remote")
func update_move_input(new_direction: Vector2) -> void:
	if not multiplayer.is_server(): return
	direction = new_direction.normalized()

# Добавляет положение игрока в буффер
@rpc("any_peer", "reliable", "call_remote")
func sync_position(new_position: Vector2, new_direction: Vector2, server_time: float) -> void:
	if not is_multiplayer_authority():
		last_direction = direction
		direction = new_direction
		if last_direction != direction:
			changed_direction.emit(direction)
	state_buffer.append({"pos": new_position, "time": server_time})

# Ключ абилки, ключ для клавиши и ключ анимации должны совпадать, чтобы все работало
@rpc("any_peer", "reliable", "call_remote")
func sync_ability(ability_idx: int):
	used_ability.emit("ability" + str(ability_idx))
	abilities_instances[ability_idx].use(self)
	_stop_moving_while_use_ability(ability_idx)

@rpc("any_peer", "unreliable", "call_remote")
func sync_parametrs(new_health: float, new_mana: float, new_stamina: float) -> void:
	health = new_health
	mana = new_mana
	stamina = new_stamina
	parametrs_changed.emit(new_health, new_mana, new_stamina)

# Вызывает rpc синхронизирующие состояние игрока
func broadcast_state():
	var server_time = Time.get_ticks_msec() / 1000.0
	sync_position.rpc(global_position, direction, server_time)

# Передвигает игрока локально 
# TODO нужно доделать prediction так как, при большой задержке будет плозая отзывчивость
func _interpolate_position():
	if state_buffer.size() < 2: return

	# время которое мы отображаем сейчас
	var render_time = Time.get_ticks_msec() / 1000.0 - HighLevelMultiplayerHandler.BUFFER_TIME

	# ищем два состояния вокруг render_time
	var prev_state = null
	var next_state = null
	for i in range(state_buffer.size()):
		var s = state_buffer[i]
		if s.time <= render_time:
			prev_state = s
		elif s.time > render_time:
			next_state = s
			break

	# если с состояния нашлись, перемещаем игрока
	if prev_state and next_state:
		var t = (render_time - prev_state.time) / (next_state.time - prev_state.time)
		global_position = prev_state.pos.lerp(next_state.pos, t)

	# чистим старые состояния
	while state_buffer.size() > 0 and state_buffer[0].time < render_time - 0.5:
		state_buffer.pop_front()

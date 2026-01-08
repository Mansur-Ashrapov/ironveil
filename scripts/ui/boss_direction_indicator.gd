extends Control
class_name BossDirectionIndicator

## Индикатор направления к боссу - стрелка с черепом

@export var arrow_distance_from_center: float = 120.0  # Расстояние от центра экрана
@export var hide_when_boss_visible: bool = true  # Скрывать когда босс виден на экране
@export var boss_visible_margin: float = 100.0  # Отступ от края экрана
@export var display_duration: float = 10.0  # Время показа индикатора (секунды)
@export var blink_speed: float = 3.0  # Скорость мигания

var player: PlayerBase
var boss: Node2D
var arrow_container: Control

# Состояние
var is_boss_alive: bool = true
var display_timer: float = 0.0
var blink_timer: float = 0.0
var is_indicator_active: bool = false


func _ready() -> void:
	# Создаем контейнер для стрелки и черепа
	_create_indicator_ui()
	
	# Скрываем пока игра не началась
	visible = false


func _create_indicator_ui() -> void:
	# Контейнер который будет вращаться (относительно центра экрана)
	arrow_container = Control.new()
	arrow_container.name = "ArrowContainer"
	arrow_container.size = Vector2(200, 200)
	arrow_container.position = Vector2(-100, -100)  # Центрируем контейнер
	arrow_container.pivot_offset = Vector2(100, 100)  # Точка вращения = центр контейнера
	add_child(arrow_container)
	
	# Стрелка (рисуем через _draw)
	var arrow_node = Control.new()
	arrow_node.name = "Arrow"
	arrow_node.size = Vector2(60, 80)
	arrow_node.position = Vector2(70, 100 + arrow_distance_from_center)  # Относительно центра контейнера
	arrow_container.add_child(arrow_node)
	
	# Добавляем скрипт для рисования стрелки
	var arrow_script = load("res://scripts/ui/boss_arrow_draw.gd")
	arrow_node.set_script(arrow_script)
	arrow_node.queue_redraw()
	
	# Череп под стрелкой (используем Unicode символ)
	var skull_label = Label.new()
	skull_label.name = "SkullLabel"
	skull_label.text = "💀"
	skull_label.add_theme_font_size_override("font_size", 32)
	skull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skull_label.size = Vector2(40, 40)
	skull_label.position = Vector2(80, 100 + arrow_distance_from_center + 55)  # Под стрелкой
	arrow_container.add_child(skull_label)


func setup(player_ref: PlayerBase) -> void:
	player = player_ref
	
	# Откладываем подключение к сигналам до момента когда узел будет в дереве
	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	if not is_inside_tree():
		return
	
	# Подключаемся к сигналу начала игры
	var root_node = get_tree().get_first_node_in_group("root")
	
	if root_node:
		var gm = root_node.get_node_or_null("%GameManager")
		
		if gm:
			if not gm.game_started.is_connected(_on_game_started):
				gm.game_started.connect(_on_game_started)
			if not gm.victory.is_connected(_on_victory):
				gm.victory.connect(_on_victory)
			
			# Проверяем - если игра уже началась, показываем индикатор
			if gm.is_game_started:
				_on_game_started()
	
	# Ищем босса
	_find_boss()


func _find_boss() -> void:
	if not is_inside_tree():
		return
	
	# Пробуем найти босса в сцене
	var bosses = get_tree().get_nodes_in_group("boss")
	
	if bosses.size() > 0:
		boss = bosses[0] as Node2D
		# Подключаемся к сигналу смерти босса если это Boss класс
		if boss.has_signal("boss_defeated"):
			if not boss.boss_defeated.is_connected(_on_boss_defeated):
				boss.boss_defeated.connect(_on_boss_defeated)


func _on_game_started() -> void:
	# Показываем индикатор когда игра началась
	_find_boss()
	
	# Показываем индикатор и запускаем таймер
	if is_boss_alive:
		visible = true
		is_indicator_active = true
		display_timer = display_duration
		blink_timer = 0.0


func _on_victory() -> void:
	is_boss_alive = false
	is_indicator_active = false
	visible = false


func _on_boss_defeated() -> void:
	is_boss_alive = false
	is_indicator_active = false
	visible = false


func _process(delta: float) -> void:
	if not is_indicator_active:
		return
	
	# Обновляем таймер показа
	display_timer -= delta
	if display_timer <= 0:
		is_indicator_active = false
		visible = false
		return
	
	# Мигание
	blink_timer += delta * blink_speed
	var blink_alpha = (sin(blink_timer * PI * 2) + 1.0) / 2.0  # Плавное мигание от 0.3 до 1.0
	blink_alpha = 0.3 + blink_alpha * 0.7
	arrow_container.modulate.a = blink_alpha
	
	# Если босс не найден - пробуем найти
	if not boss or not is_instance_valid(boss):
		_find_boss()
		if not boss:
			return
	
	if not is_boss_alive:
		visible = false
		is_indicator_active = false
		return
	
	if not player:
		return
	
	# Рассчитываем направление к боссу
	var direction_to_boss = (boss.global_position - player.global_position).normalized()
	
	# Проверяем виден ли босс на экране
	if hide_when_boss_visible and _is_boss_on_screen():
		arrow_container.visible = false
		return
	else:
		arrow_container.visible = true
	
	# Вращаем контейнер чтобы указывать на босса
	# Угол от центра к боссу (стрелка смотрит вниз при rotation=0, поэтому вычитаем PI/2)
	var angle = direction_to_boss.angle() - PI / 2
	arrow_container.rotation = angle


func _is_boss_on_screen() -> bool:
	if not player or not boss:
		return false
	
	# Получаем размер экрана
	var viewport_size = get_viewport().get_visible_rect().size
	var half_size = viewport_size / 2
	
	# Позиция босса относительно игрока (центра камеры)
	var boss_relative_pos = boss.global_position - player.global_position
	
	# Проверяем находится ли босс в пределах экрана с отступом
	var margin = boss_visible_margin
	if abs(boss_relative_pos.x) < half_size.x - margin and abs(boss_relative_pos.y) < half_size.y - margin:
		return true
	
	return false

extends Node2D
class_name BossMarkEffect

# Визуальный эффект метки босса над игроком
# Пульсирующий круг предупреждения перед специальной атакой

const BASE_RADIUS: float = 40.0
const MAX_RADIUS: float = 60.0
const PULSE_SPEED: float = 8.0
const ROTATION_SPEED: float = 3.0

var duration: float = 1.0
var elapsed_time: float = 0.0
var current_radius: float = BASE_RADIUS
var alpha: float = 1.0

# Цвета
var outer_color: Color = Color(0.9, 0.2, 0.2, 0.8)  # Красный внешний
var inner_color: Color = Color(1.0, 0.4, 0.1, 0.6)  # Оранжевый внутренний
var warning_color: Color = Color(1.0, 1.0, 0.2, 0.9)  # Желтый для предупреждения


func setup(mark_duration: float) -> void:
	duration = mark_duration
	z_index = 100  # Поверх всего


func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Прогресс от 0 до 1
	var progress = clamp(elapsed_time / duration, 0.0, 1.0)
	
	# Пульсация радиуса
	var pulse = sin(elapsed_time * PULSE_SPEED)
	current_radius = BASE_RADIUS + (MAX_RADIUS - BASE_RADIUS) * (0.5 + 0.5 * pulse)
	
	# Увеличение интенсивности к концу
	alpha = 0.6 + 0.4 * progress
	
	# Вращение
	rotation += ROTATION_SPEED * delta
	
	# Уничтожаем после окончания времени
	if elapsed_time >= duration:
		queue_free()
	
	queue_redraw()


func _draw() -> void:
	var progress = clamp(elapsed_time / duration, 0.0, 1.0)
	
	# Внешнее кольцо (пульсирующее)
	var ring_color = outer_color
	ring_color.a = alpha * 0.7
	_draw_ring(Vector2.ZERO, current_radius, ring_color, 4.0)
	
	# Внутренний круг
	var inner_col = inner_color
	inner_col.a = alpha * 0.4
	draw_circle(Vector2.ZERO, current_radius * 0.6, inner_col)
	
	# Крест/прицел внутри
	var cross_color = warning_color
	cross_color.a = alpha
	var cross_size = current_radius * 0.4
	var cross_width = 3.0
	
	# Вертикальная линия
	draw_line(Vector2(0, -cross_size), Vector2(0, cross_size), cross_color, cross_width)
	# Горизонтальная линия
	draw_line(Vector2(-cross_size, 0), Vector2(cross_size, 0), cross_color, cross_width)
	
	# Треугольники по краям (указатели опасности)
	var triangle_dist = current_radius * 0.8
	var triangle_size = 12.0
	
	for i in range(4):
		var angle = i * PI / 2
		var dir = Vector2(cos(angle), sin(angle))
		var pos = dir * triangle_dist
		_draw_warning_triangle(pos, dir, triangle_size, warning_color)
	
	# Индикатор прогресса (заполняющийся круг)
	if progress > 0:
		var fill_color = Color(1.0, 0.3, 0.3, alpha * 0.5)
		_draw_arc_fill(Vector2.ZERO, current_radius * 0.3, progress, fill_color)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments = 32
	for i in range(segments):
		var angle1 = i * TAU / segments
		var angle2 = (i + 1) * TAU / segments
		var p1 = center + Vector2(cos(angle1), sin(angle1)) * radius
		var p2 = center + Vector2(cos(angle2), sin(angle2)) * radius
		draw_line(p1, p2, color, width)


func _draw_warning_triangle(pos: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var perpendicular = Vector2(-direction.y, direction.x)
	var tip = pos + direction * size
	var base1 = pos - direction * size * 0.5 + perpendicular * size * 0.5
	var base2 = pos - direction * size * 0.5 - perpendicular * size * 0.5
	
	var points = PackedVector2Array([tip, base1, base2])
	var colors = PackedColorArray([color, color, color])
	draw_polygon(points, colors)


func _draw_arc_fill(center: Vector2, radius: float, progress: float, color: Color) -> void:
	if progress <= 0:
		return
	
	var segments = int(32 * progress)
	if segments < 2:
		return
	
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	
	points.append(center)
	colors.append(color)
	
	for i in range(segments + 1):
		var angle = -PI / 2 + (i * TAU * progress / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		colors.append(color)
	
	if points.size() >= 3:
		draw_polygon(points, colors)


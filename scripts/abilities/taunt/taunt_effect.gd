extends Node2D
class_name TauntEffect

const EXPAND_DURATION: float = 0.4
const FADE_DURATION: float = 0.3

var target_radius: float = 300.0
var current_radius: float = 0.0
var alpha: float = 1.0
var color: Color = Color(1.0, 0.3, 0.2, 0.7)  # Красноватый цвет для aggro

var expand_timer: float = 0.0
var fade_timer: float = 0.0
var is_fading: bool = false

func setup(radius: float):
	target_radius = radius

func _ready():
	z_index = 10

func _process(delta: float):
	if not is_fading:
		# Фаза расширения
		expand_timer += delta
		var t = clamp(expand_timer / EXPAND_DURATION, 0.0, 1.0)
		# Easing - начинается быстро, замедляется
		t = 1.0 - pow(1.0 - t, 3)
		current_radius = target_radius * t
		
		if expand_timer >= EXPAND_DURATION:
			is_fading = true
	else:
		# Фаза затухания
		fade_timer += delta
		var t = clamp(fade_timer / FADE_DURATION, 0.0, 1.0)
		alpha = 1.0 - t
		
		if fade_timer >= FADE_DURATION:
			queue_free()
	
	queue_redraw()

func _draw():
	var draw_color = color
	draw_color.a = alpha * 0.5
	
	# Рисуем заполненный круг (полупрозрачный)
	draw_circle(Vector2.ZERO, current_radius, draw_color)
	
	# Рисуем контур кольца (более яркий)
	var ring_color = color
	ring_color.a = alpha
	var ring_width = 4.0
	var segments = 64
	
	for i in range(segments):
		var angle1 = i * TAU / segments
		var angle2 = (i + 1) * TAU / segments
		var p1 = Vector2(cos(angle1), sin(angle1)) * current_radius
		var p2 = Vector2(cos(angle2), sin(angle2)) * current_radius
		draw_line(p1, p2, ring_color, ring_width)


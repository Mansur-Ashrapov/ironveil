extends Control

## Рисует стрелку указывающую направление к боссу

var arrow_color: Color = Color(0.9, 0.2, 0.2, 0.9)  # Красный цвет
var outline_color: Color = Color(0.1, 0.1, 0.1, 0.9)  # Темный контур
var outline_width: float = 3.0


func _draw() -> void:
	# Размеры стрелки
	var width = 60.0
	var height = 50.0
	var center_x = width / 2
	
	# Точки стрелки (треугольник указывающий вниз)
	var points = PackedVector2Array([
		Vector2(center_x, height),       # Нижний конец (острие)
		Vector2(0, 0),                    # Левый верхний угол
		Vector2(width * 0.3, 0),          # Левая внутренняя точка
		Vector2(width * 0.3, -height * 0.3),  # Левый хвост
		Vector2(width * 0.7, -height * 0.3),  # Правый хвост
		Vector2(width * 0.7, 0),          # Правая внутренняя точка
		Vector2(width, 0),                # Правый верхний угол
	])
	
	# Рисуем контур
	var outline_points = points.duplicate()
	outline_points.append(points[0])  # Замыкаем контур
	draw_polyline(outline_points, outline_color, outline_width + 2)
	
	# Рисуем заливку
	draw_colored_polygon(points, arrow_color)
	
	# Рисуем контур поверх
	draw_polyline(outline_points, outline_color, outline_width)


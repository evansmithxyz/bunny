extends Node2D
## A bird the bunny can bounce on. Flies sideways and wraps around the screen.

const BODY_HALF_HEIGHT := 14.0

var kind := "sparrow"
var width := 90.0
var speed := 150.0
var direction := 1.0
var bounce_multiplier := 1.0
var flap_speed := 12.0
var body_color := Color(0.6, 0.42, 0.28)
var wing_color := Color(0.45, 0.3, 0.2)
var screen_width := 720.0

var _flap_time := 0.0
var _dip := 0.0 # Visual dip when landed on.


func setup(bird_kind: String, difficulty: float, screen_w: float) -> void:
	kind = bird_kind
	screen_width = screen_w
	match kind:
		"pigeon": # Big and slow: a safe landing.
			width = 130.0
			speed = 70.0
			bounce_multiplier = 0.95
			body_color = Color(0.62, 0.64, 0.7)
			wing_color = Color(0.46, 0.48, 0.55)
		"hummingbird": # Small and fast, but gives a super bounce.
			width = 56.0
			speed = 260.0
			bounce_multiplier = 1.45
			flap_speed = 45.0
			body_color = Color(0.2, 0.75, 0.45)
			wing_color = Color(0.65, 0.95, 0.85)
		_: # Sparrow
			width = 90.0
			speed = randf_range(120.0, 180.0)
	speed *= 1.0 + difficulty * 0.8
	direction = 1.0 if randf() < 0.5 else -1.0
	_flap_time = randf() * TAU


func step(delta: float) -> void:
	position.x += speed * direction * delta
	if direction > 0.0 and position.x > screen_width + width:
		position.x = -width
	elif direction < 0.0 and position.x < -width:
		position.x = screen_width + width
	_flap_time += delta * flap_speed
	_dip = move_toward(_dip, 0.0, 80.0 * delta)
	queue_redraw()


func top_y() -> float:
	return position.y - BODY_HALF_HEIGHT


func half_width() -> float:
	return width * 0.5


func hit() -> void:
	_dip = 16.0


func _draw() -> void:
	var off := Vector2(0, _dip)
	var rx := width * 0.5
	var head := off + Vector2(direction * rx * 0.85, -6)

	# Body
	draw_set_transform(off, 0.0, Vector2(rx / BODY_HALF_HEIGHT, 1.0))
	draw_circle(Vector2.ZERO, BODY_HALF_HEIGHT, body_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Head, beak, eye
	draw_circle(head, 11, body_color)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(direction * 8, -4),
		head + Vector2(direction * 20, 0),
		head + Vector2(direction * 8, 4),
	]), Color(1.0, 0.75, 0.2))
	draw_circle(head + Vector2(direction * 3, -3), 2.5, Color(0.1, 0.1, 0.12))

	# Wing (skipped when edge-on, which would be a flat triangle)
	var tip_y := -6.0 + 22.0 * sin(_flap_time)
	if absf(tip_y + 4.0) > 3.0:
		draw_colored_polygon(PackedVector2Array([
			off + Vector2(-rx * 0.35, -4),
			off + Vector2(rx * 0.25, -4),
			off + Vector2(-direction * rx * 0.2, tip_y),
		]), wing_color)

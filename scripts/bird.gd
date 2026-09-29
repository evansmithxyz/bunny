extends Node2D
## A bird the bunny can bounce on. Flies sideways and wraps around the screen.

const Bunny := preload("res://scripts/bunny.gd")

signal dove # Crow only: emitted when it swoops away from the bunny.

const BODY_HALF_HEIGHT := 14.0

# Crow swoop (once per crow): drops down and speeds up sideways, then climbs back.
const CROW_TRIGGER_DISTANCE := 150.0
const CROW_DIVE_SPEED := 750.0
const CROW_DIVE_RECOVERY := 1400.0
const CROW_DIVE_SIDE_BOOST := 1.8

var kind := "sparrow"
var width := 90.0
var speed := 150.0
var direction := 1.0
var bounce_multiplier := 1.0
var flap_speed := 12.0
var body_color := Color(0.6, 0.42, 0.28)
var wing_color := Color(0.45, 0.3, 0.2)
var beak_color := Color(1.0, 0.75, 0.2)
var eye_color := Color(0.1, 0.1, 0.12)
var screen_width := 720.0
var prev_top := 0.0 # top_y() before this frame's movement, for landing checks.

var _flap_time := 0.0
var _dip := 0.0 # Visual dip when landed on.
var _home_y := 0.0
var _dive_velocity := 0.0
var _diving := false
var _has_dived := false


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
		"crow": # Swoops away as you come down on it.
			width = 95.0
			speed = 130.0
			bounce_multiplier = 1.05
			body_color = Color(0.13, 0.13, 0.17)
			wing_color = Color(0.24, 0.24, 0.3)
			beak_color = Color(0.3, 0.3, 0.33)
			eye_color = Color(0.95, 0.25, 0.2)
		"goose": # Big, slow, and knocks you sideways when you land.
			width = 120.0
			speed = 90.0
			bounce_multiplier = 1.0
			flap_speed = 8.0
			body_color = Color(0.96, 0.96, 0.93)
			wing_color = Color(0.8, 0.8, 0.78)
			beak_color = Color(1.0, 0.55, 0.15)
		_: # Sparrow
			width = 90.0
			speed = randf_range(120.0, 180.0)
	speed *= 1.0 + difficulty * 0.8
	direction = 1.0 if randf() < 0.5 else -1.0
	_flap_time = randf() * TAU


func _ready() -> void:
	_home_y = position.y
	prev_top = top_y()


func step(delta: float, bunny: Bunny) -> void:
	prev_top = top_y()
	var side_speed := speed
	if kind == "crow":
		_update_crow(delta, bunny)
		if _diving:
			side_speed *= CROW_DIVE_SIDE_BOOST

	# Wraps seamlessly like the bunny: x always stays in [0, width).
	position.x = fposmod(position.x + side_speed * direction * delta, screen_width)
	_flap_time += delta * (flap_speed * 2.0 if _diving else flap_speed)
	_dip = move_toward(_dip, 0.0, 80.0 * delta)
	queue_redraw()


func _update_crow(delta: float, bunny: Bunny) -> void:
	if not _has_dived and bunny.velocity.y > 0.0:
		var gap := top_y() - (bunny.position.y + Bunny.FEET)
		var lined_up := absf(Bunny.wrapped_dx(bunny.position.x, position.x, screen_width)) < width
		if gap > 0.0 and gap < CROW_TRIGGER_DISTANCE and lined_up:
			_diving = true
			_has_dived = true
			_dive_velocity = CROW_DIVE_SPEED
			dove.emit()
	if _diving:
		_dive_velocity -= CROW_DIVE_RECOVERY * delta
		position.y += _dive_velocity * delta
		if _dive_velocity < 0.0 and position.y <= _home_y:
			position.y = _home_y
			_diving = false


func top_y() -> float:
	return position.y - BODY_HALF_HEIGHT


func half_width() -> float:
	return width * 0.5


func hit() -> void:
	_dip = 16.0


func _draw() -> void:
	# Near an edge, also draw a copy on the other side so wrapping is seamless.
	var extent := width * 0.5 + 25.0 # Body plus head and beak.
	_draw_bird(Vector2(0, _dip))
	if position.x + extent > screen_width:
		_draw_bird(Vector2(-screen_width, _dip))
	if position.x - extent < 0.0:
		_draw_bird(Vector2(screen_width, _dip))


func _draw_bird(off: Vector2) -> void:
	var rx := width * 0.5
	var head := off + Vector2(direction * rx * 0.85, -6)
	if kind == "goose":
		# Long neck: head sits further forward and up.
		head = off + Vector2(direction * rx * 0.95, -30)
		draw_line(off + Vector2(direction * rx * 0.55, -4), head, body_color, 12.0)

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
	]), beak_color)
	draw_circle(head + Vector2(direction * 3, -3), 2.5, eye_color)

	# Wing (skipped when edge-on, which would be a flat triangle)
	var tip_y := -6.0 + 22.0 * sin(_flap_time)
	if absf(tip_y + 4.0) > 3.0:
		draw_colored_polygon(PackedVector2Array([
			off + Vector2(-rx * 0.35, -4),
			off + Vector2(rx * 0.25, -4),
			off + Vector2(-direction * rx * 0.2, tip_y),
		]), wing_color)

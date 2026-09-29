extends Node2D
## The player. Bounces automatically when it lands; tilt the phone (or use
## the arrow keys on a PC) to steer left and right.

signal bounced

const GRAVITY := 1800.0
const JUMP_VELOCITY := 1100.0
const MAX_SIDE_SPEED := 800.0
const HALF_WIDTH := 22.0
const FEET := 30.0 # Distance from the bunny's center down to its feet.

# Tilt tuning. If the bunny moves the wrong way when you tilt, set INVERT_TILT.
const TILT_SENSITIVITY := 3.0
const TILT_DEAD_ZONE := 0.03
const INVERT_TILT := false

const FUR := Color(0.97, 0.95, 0.92)
const PINK := Color(0.98, 0.66, 0.72)
const EYE := Color(0.1, 0.1, 0.12)

var velocity := Vector2.ZERO
var screen_width := 720.0
var facing := 1.0

var _knocked_time := 0.0 # Steering is disabled while knocked sideways.


func step(delta: float) -> void:
	if _knocked_time > 0.0:
		_knocked_time -= delta
		velocity.x = lerpf(velocity.x, 0.0, clampf(2.0 * delta, 0.0, 1.0))
	else:
		var target_x := _read_horizontal_input() * MAX_SIDE_SPEED
		velocity.x = lerpf(velocity.x, target_x, clampf(14.0 * delta, 0.0, 1.0))
	velocity.y += GRAVITY * delta
	position += velocity * delta

	# The screen wraps seamlessly, like a cylinder: x always stays in [0, width).
	position.x = fposmod(position.x, screen_width)

	if absf(velocity.x) > 20.0:
		facing = signf(velocity.x)
	scale = scale.lerp(Vector2.ONE, clampf(8.0 * delta, 0.0, 1.0))
	queue_redraw()


func bounce(multiplier: float = 1.0) -> void:
	velocity.y = -JUMP_VELOCITY * multiplier
	scale = Vector2(1.35, 0.7) # Squash on landing, springs back in step().
	bounced.emit()


## Shove the bunny sideways; steering returns after `seconds`.
func knock(side_velocity: float, seconds: float) -> void:
	velocity.x = side_velocity
	_knocked_time = seconds


## Horizontal distance from one x to another the short way around the wrap.
static func wrapped_dx(from_x: float, to_x: float, width: float) -> float:
	return fposmod(to_x - from_x + width / 2.0, width) - width / 2.0


func _read_horizontal_input() -> float:
	var keys := Input.get_axis("ui_left", "ui_right")
	if keys != 0.0:
		return keys

	var accel := Input.get_accelerometer() # Zero on PCs without a sensor.
	var tilt := accel.x / 9.8
	if INVERT_TILT:
		tilt = -tilt
	if absf(tilt) < TILT_DEAD_ZONE:
		return 0.0
	return clampf(tilt * TILT_SENSITIVITY, -1.0, 1.0)


func _draw() -> void:
	# Near an edge, also draw a copy on the other side so wrapping is seamless.
	# (Local units, so divide by scale to undo the squash animation.)
	var extent := 35.0 * scale.x
	var shift := screen_width / scale.x
	_draw_bunny(Vector2.ZERO)
	if position.x + extent > screen_width:
		_draw_bunny(Vector2(-shift, 0))
	if position.x - extent < 0.0:
		_draw_bunny(Vector2(shift, 0))


func _draw_bunny(o: Vector2) -> void:
	var ear_lean := clampf(velocity.y / 4000.0, -0.25, 0.25)
	# Ears
	_draw_ellipse(o + Vector2(-9, -40), 7, 20, FUR, -0.18 - ear_lean)
	_draw_ellipse(o + Vector2(9, -40), 7, 20, FUR, 0.18 + ear_lean)
	_draw_ellipse(o + Vector2(-9, -38), 3.5, 13, PINK, -0.18 - ear_lean)
	_draw_ellipse(o + Vector2(9, -38), 3.5, 13, PINK, 0.18 + ear_lean)
	# Tail, body, feet
	draw_circle(o + Vector2(-facing * 22, 16), 7, Color.WHITE)
	_draw_ellipse(o + Vector2(0, 8), 24, 22, FUR)
	_draw_ellipse(o + Vector2(-11, 27), 10, 4, FUR)
	_draw_ellipse(o + Vector2(11, 27), 10, 4, FUR)
	# Head
	draw_circle(o + Vector2(facing * 4, -14), 17, FUR)
	draw_circle(o + Vector2(facing * 11, -18), 3, EYE)
	draw_circle(o + Vector2(facing * 20, -11), 2.5, PINK)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, angle: float = 0.0) -> void:
	draw_set_transform(center, angle, Vector2(rx / ry, 1.0))
	draw_circle(Vector2.ZERO, ry, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

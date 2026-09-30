extends Node2D
## The player. Bounces automatically when it lands; tilt the phone (or use
## the arrow keys on a PC) to steer left and right.

signal bounced

const GRAVITY := 1800.0
const JUMP_VELOCITY := 1100.0
const MAX_SIDE_SPEED := 800.0
const HALF_WIDTH := 26.0
const FEET := 48.0 # Distance from the bunny's center down to its feet.

# Tilt tuning. If the bunny moves the wrong way when you tilt, set INVERT_TILT.
const TILT_SENSITIVITY := 3.0
const TILT_DEAD_ZONE := 0.03
const INVERT_TILT := false

# Kenney Jumper Pack sprites (CC0), drawn with their feet at FEET.
const SPRITE_SCALE := 0.5
const BROWN := {
	"stand": preload("res://assets/kenney/bunny1_stand.png"),
	"ready": preload("res://assets/kenney/bunny1_ready.png"),
	"jump": preload("res://assets/kenney/bunny1_jump.png"),
	"hurt": preload("res://assets/kenney/bunny1_hurt.png"),
}
const PURPLE := { # Easter egg skin: tap the menu title 7 times.
	"stand": preload("res://assets/kenney/bunny2_stand.png"),
	"ready": preload("res://assets/kenney/bunny2_ready.png"),
	"jump": preload("res://assets/kenney/bunny2_jump.png"),
	"hurt": preload("res://assets/kenney/bunny2_hurt.png"),
}
const READY_TIME := 0.1 # How long the crouch pose shows after landing.

var velocity := Vector2.ZERO
var screen_width := 720.0
var hurt := false # Shows the hurt face (set on game over).
var controls_enabled := true # Off on the menu, where the bunny just hops in place.
var purple := false:
	set(value):
		purple = value
		queue_redraw()

var _knocked_time := 0.0 # Steering is disabled while knocked sideways.
var _ready_time := 0.0
var _squash := Vector2.ONE # Stretch around the feet, springs back to 1.


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

	_ready_time -= delta
	_squash = _squash.lerp(Vector2.ONE, clampf(8.0 * delta, 0.0, 1.0))
	queue_redraw()


func bounce(multiplier: float = 1.0) -> void:
	velocity.y = -JUMP_VELOCITY * multiplier
	_squash = Vector2(1.3, 0.72) # Squash on landing, springs back in step().
	_ready_time = READY_TIME
	bounced.emit()


## Shove the bunny sideways; steering returns after `seconds`.
func knock(side_velocity: float, seconds: float) -> void:
	velocity.x = side_velocity
	_knocked_time = seconds


## Horizontal distance from one x to another the short way around the wrap.
static func wrapped_dx(from_x: float, to_x: float, width: float) -> float:
	return fposmod(to_x - from_x + width / 2.0, width) - width / 2.0


func _read_horizontal_input() -> float:
	if not controls_enabled:
		return 0.0
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


func _current_texture() -> Texture2D:
	var skin := PURPLE if purple else BROWN
	if hurt or _knocked_time > 0.0:
		return skin.hurt
	if _ready_time > 0.0:
		return skin.ready
	if velocity.y < -250.0:
		return skin.jump # Legs kicked out while rising fast.
	return skin.stand # Legs down, ready to land.


func _draw() -> void:
	# Near an edge, also draw a copy on the other side so wrapping is seamless.
	var extent := 40.0
	_draw_bunny(0.0)
	if position.x + extent > screen_width:
		_draw_bunny(-screen_width)
	if position.x - extent < 0.0:
		_draw_bunny(screen_width)


func _draw_bunny(shift_x: float) -> void:
	var tex := _current_texture()
	var size := tex.get_size() * SPRITE_SCALE
	var lean := clampf(velocity.x / MAX_SIDE_SPEED, -1.0, 1.0) * 0.18
	# Pivot at the feet so squash and lean happen around where it lands.
	draw_set_transform(Vector2(shift_x, FEET), lean, _squash)
	draw_texture_rect(tex, Rect2(-size.x / 2.0, -size.y, size.x, size.y), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends Node2D
## The player. Bounces automatically when it lands; tilt the phone (or use
## the arrow keys on a PC) to steer left and right.
##
## Drawn in three layers so shop colors only recolor the bunny itself:
## this node draws gear behind (jetpack, wings), a child draws the body (with
## the color shader), and another child draws the hat and bubble in front.

signal bounced

const Catalog := preload("res://scripts/catalog.gd")

const GRAVITY := 1800.0
const JUMP_VELOCITY := 1100.0
const MAX_SIDE_SPEED := 800.0
const HALF_WIDTH := 26.0
const FEET := 48.0 # Distance from the bunny's center down to its feet.

# Tilt steering measures how far the phone leans away from "center". Center is
# the phone held upright by default, or whatever angle the player saved with
# "Set center" on the tilt screen. Readings are -1 to 1 (sine of the angle).
const TILT_SENSITIVITY := 3.0 # Full speed at about 20 degrees, before the player's multiplier.
const TILT_DEAD_ZONE := 0.03
const TILT_SIDEWAYS_SWITCH := 0.25 # See calibrate_right.

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

# Hats sit on the top of the head, which is at a different height in each pose
# (measured from the sprites, in game pixels above the feet).
const HEAD_TOP := {"stand": -76.0, "ready": -71.0, "jump": -66.0, "hurt": -67.0}
const HAT_SINK := 5.0 # Hats sit a little down onto the head.

# Power-ups (Kenney art). Gear blinks during its last second as a warning.
const JETPACK_TIME := 2.0 # Before shop upgrades.
const JETPACK_SPEED := 1200.0 # Straight up while it's firing.
const WINGS_TIME := 6.0 # Before shop upgrades.
const WINGS_MAX_FALL := 260.0 # Gliding: falls no faster than this.
const TEX_JETPACK := preload("res://assets/kenney/jetpack.png")
const TEX_FLAME := preload("res://assets/kenney/flame.png")
const TEX_WING_LEFT := preload("res://assets/kenney/wing_left.png")
const TEX_WING_RIGHT := preload("res://assets/kenney/wing_right.png")
const TEX_BUBBLE := preload("res://assets/kenney/bubble.png")
const TEX_SPRING := preload("res://assets/art/spring_coil.svg")
const SPRING_FEET_X := 11.0 # Springs hang under each foot.

## A child node that draws one layer by calling back into the bunny.
class Layer extends Node2D:
	var painter: Callable

	func _init(paint: Callable) -> void:
		painter = paint

	func _draw() -> void:
		painter.call(self)


var velocity := Vector2.ZERO
var screen_width := 720.0
var hurt := false # Shows the hurt face (set on game over).
var controls_enabled := true # Off on the menu, where the bunny just hops in place.
var tilt_right := Vector3.RIGHT # Direction that counts as "tilt right" (see calibrate_right).
var tilt_sensitivity := 1.0 # Player's multiplier from the tilt screen.
var control_mode := "tilt" # "tilt" or "touch" (hold the left/right side of the screen).
var color := "brown": # A Catalog.COLORS id.
	set(value):
		color = value
		_apply_color()
var hat := "none" # A Catalog.HATS id.
var trail := "none": # A Catalog.TRAILS id.
	set(value):
		trail = value
		_apply_trail()

var jetpack_duration := JETPACK_TIME # Longer with the shop upgrade.
var wings_duration := WINGS_TIME
var jetpack_time := 0.0 # Seconds of jetpack left.
var wings_time := 0.0 # Seconds of gliding left.
var has_bubble := false # Saves the bunny once from falling off the screen.
var spring_bounces := 0 # Spring shoes: this many super bounces left.

var _body: Layer
var _front: Layer
var _trail_particles: CPUParticles2D
var _touches := {} # Touch index -> x. In order of pressing, so the newest is last.
var _knocked_time := 0.0 # Steering is disabled while knocked sideways.
var _anim_time := 0.0
var _ready_time := 0.0
var _squash := Vector2.ONE # Stretch around the feet, springs back to 1.


func _ready() -> void:
	_trail_particles = _make_trail_particles() # First, so it draws behind the body.
	add_child(_trail_particles)
	_body = Layer.new(_paint_body)
	_front = Layer.new(_paint_front)
	add_child(_body)
	add_child(_front)
	_apply_color()
	_apply_trail()


func step(delta: float) -> void:
	if _knocked_time > 0.0:
		_knocked_time -= delta
		velocity.x = lerpf(velocity.x, 0.0, clampf(2.0 * delta, 0.0, 1.0))
	else:
		var target_x := _read_horizontal_input() * MAX_SIDE_SPEED
		velocity.x = lerpf(velocity.x, target_x, clampf(14.0 * delta, 0.0, 1.0))
	if jetpack_time > 0.0:
		jetpack_time -= delta
		# Full thrust, then coast upward a bit when it runs out.
		velocity.y = -JETPACK_SPEED if jetpack_time > 0.0 else -JETPACK_SPEED * 0.6
	else:
		velocity.y += GRAVITY * delta
		if wings_time > 0.0:
			velocity.y = minf(velocity.y, WINGS_MAX_FALL)
	wings_time = maxf(wings_time - delta, 0.0)
	position += velocity * delta

	# The screen wraps seamlessly, like a cylinder: x always stays in [0, width).
	position.x = fposmod(position.x, screen_width)

	_ready_time -= delta
	_anim_time += delta
	_squash = _squash.lerp(Vector2.ONE, clampf(8.0 * delta, 0.0, 1.0))
	if _trail_particles:
		_trail_particles.emitting = trail != "none" and velocity.length() > 150.0
	redraw()


## Redraws all three layers (also call after changing the hat or hurt).
func redraw() -> void:
	queue_redraw()
	if _body:
		_body.queue_redraw()
		_front.queue_redraw()


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
	if control_mode == "touch":
		return touch_direction()
	return steer(tilt_amount(Input.get_accelerometer(), tilt_right), tilt_sensitivity)


# --- Touch steering -------------------------------------------------------------
# Taps on buttons (like pause) are handled by the UI first and never get here.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touches.erase(event.index) # Re-added at the end, so the newest press wins.
		if event.pressed:
			_touches[event.index] = event.position.x
	elif event is InputEventScreenDrag:
		# Also picks up a finger that stayed down through a pause (its press was
		# cleared), so steering resumes as soon as it moves.
		_touches[event.index] = event.position.x
	elif not DisplayServer.is_touchscreen_available():
		# Mouse stands in for a finger on a PC (phones send real touches instead).
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_touches.erase(-1)
			if event.pressed:
				_touches[-1] = event.position.x
		elif event is InputEventMouseMotion and _touches.has(-1):
			_touches[-1] = event.position.x


## -1 while holding the left half of the screen, 1 for the right half, else 0.
func touch_direction() -> float:
	if _touches.is_empty():
		return 0.0
	var x: float = _touches.values()[-1]
	return 1.0 if x >= get_viewport_rect().size.x / 2.0 else -1.0


## Forgets fingers that are down, e.g. when a pause screen swallows the release.
func clear_touches() -> void:
	_touches.clear()


# --- Shop trail -----------------------------------------------------------------

func _make_trail_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false # Particles stay where they were dropped, making a trail.
	p.emitting = false
	p.amount = 28
	p.lifetime = 0.8
	p.position = Vector2(0, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2.DOWN
	p.spread = 60.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2.ZERO
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.85
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


func _apply_trail() -> void:
	if _trail_particles == null:
		return
	var item := Catalog.find(Catalog.TRAILS, trail)
	_trail_particles.texture = item.get("texture")
	if trail == "none":
		_trail_particles.emitting = false


## How far the phone leans right (+) or left (-) of center: -1 to 1.
## `accel` is a raw accelerometer reading (zero on PCs without a sensor).
static func tilt_amount(accel: Vector3, right: Vector3) -> float:
	if accel.length() < 0.1:
		return 0.0
	return accel.normalized().dot(right)


## Turns a tilt reading into steering: dead zone, sensitivity, -1 to 1.
static func steer(tilt: float, sensitivity: float) -> float:
	if absf(tilt) < TILT_DEAD_ZONE:
		return 0.0
	return clampf(tilt * TILT_SENSITIVITY * sensitivity, -1.0, 1.0)


## The "right" direction to steer by when the phone rests like `accel`: the
## phone's own sideways axis, with the part along gravity removed, so that
## resting position reads as zero and tilting either way reads the same amount.
##
## Lying on your side, the sideways axis points almost straight down and can't
## be used, so the phone's up axis is used instead (signed to match). For the
## "steering wheel" motion both give exactly the same direction, so the switch
## is seamless. Returns Vector3.ZERO only when there's no sensor.
static func calibrate_right(accel: Vector3) -> Vector3:
	if accel.length() < 0.1:
		return Vector3.ZERO
	var down := accel.normalized()
	var right := Vector3.RIGHT - down * Vector3.RIGHT.dot(down)
	if right.length() < TILT_SIDEWAYS_SWITCH:
		right = (Vector3.UP - down * Vector3.UP.dot(down)) * -signf(down.x)
	return right.normalized()


func _apply_color() -> void:
	if _body:
		_body.material = Catalog.color_material(color)
	redraw()


func _current_pose() -> String:
	if hurt or _knocked_time > 0.0:
		return "hurt"
	if _ready_time > 0.0:
		return "ready"
	if velocity.y < -250.0:
		return "jump" # Legs kicked out while rising fast.
	return "stand" # Legs down, ready to land.


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	_paint(self, _paint_back_at)


func _paint_body(layer: CanvasItem) -> void:
	_paint(layer, _paint_body_at)


func _paint_front(layer: CanvasItem) -> void:
	_paint(layer, _paint_front_at)


## Calls `painter` once per copy of the bunny: near an edge, a second copy is
## drawn on the other side so wrapping is seamless.
func _paint(ci: CanvasItem, painter: Callable) -> void:
	var extent := 70.0 # Wide enough for wings and the bubble.
	var shifts := [0.0]
	if position.x + extent > screen_width:
		shifts.append(-screen_width)
	if position.x - extent < 0.0:
		shifts.append(screen_width)
	var lean := clampf(velocity.x / MAX_SIDE_SPEED, -1.0, 1.0) * 0.18
	for shift_x: float in shifts:
		# Everything is placed relative to the feet, so squash and lean happen
		# around where it lands. The body spans roughly y = -100 to 0.
		painter.call(ci, Transform2D(lean, _squash, 0.0, Vector2(shift_x, FEET)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _paint_back_at(ci: CanvasItem, base: Transform2D) -> void:
	if spring_bounces > 0:
		# A spring under each foot; squashed for a moment after landing.
		var squash := 0.55 if _ready_time > 0.0 else 1.0
		for side in [-1.0, 1.0]:
			ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.5, 0.5 * squash), 0.0, Vector2(SPRING_FEET_X * side, -2.0)))
			ci.draw_texture(TEX_SPRING, Vector2(-TEX_SPRING.get_width() / 2.0, 0.0))
	if _gear_visible(jetpack_time):
		_draw_piece(ci, base, TEX_JETPACK, TEX_JETPACK.get_size() / 2.0, Vector2(0, -48), 0.0, 0.65)
		if jetpack_time > 0.0:
			# Flickering flames under both nozzles.
			for side in [-1.0, 1.0]:
				var flicker := 0.8 + 0.4 * absf(sin(_anim_time * 40.0 + side))
				ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.45, 0.45 * flicker), 0.0, Vector2(29 * side, 4)))
				ci.draw_texture(TEX_FLAME, Vector2(-TEX_FLAME.get_width() / 2.0, 0))
	if _gear_visible(wings_time):
		var flap := sin(_anim_time * 14.0) * 0.35
		_draw_piece(ci, base, TEX_WING_LEFT, Vector2(80, 14), Vector2(-16, -62), flap, 0.6)
		_draw_piece(ci, base, TEX_WING_RIGHT, Vector2(5, 14), Vector2(16, -62), -flap, 0.6)


func _paint_body_at(ci: CanvasItem, base: Transform2D) -> void:
	var skin := PURPLE if color == "purple" else BROWN
	var tex: Texture2D = skin[_current_pose()]
	var size := tex.get_size() * SPRITE_SCALE
	ci.draw_set_transform_matrix(base)
	ci.draw_texture_rect(tex, Rect2(-size.x / 2.0, -size.y, size.x, size.y), false)


func _paint_front_at(ci: CanvasItem, base: Transform2D) -> void:
	var hat_item := Catalog.find(Catalog.HATS, hat)
	if hat_item.has("texture"):
		var tex: Texture2D = hat_item.texture
		var pivot: Vector2 = hat_item.get("pivot", Vector2(tex.get_width() / 2.0, tex.get_height())) # Default: bottom middle.
		var at := Vector2(0, HEAD_TOP[_current_pose()] + HAT_SINK)
		_draw_piece(ci, base, tex, pivot, at, 0.0, SPRITE_SCALE * hat_item.scale)
	if has_bubble:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.62, 0.62), 0.0, Vector2(0, -50)))
		ci.draw_texture(TEX_BUBBLE, -TEX_BUBBLE.get_size() / 2.0, Color(1, 1, 1, 0.7))


## Draws `tex` rotated by `angle` around its `pivot` pixel, placed at `at`.
func _draw_piece(ci: CanvasItem, base: Transform2D, tex: Texture2D, pivot: Vector2, at: Vector2, angle: float, s: float) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(angle, Vector2(s, s), 0.0, at))
	ci.draw_texture(tex, -pivot)


## Gear shows while its timer runs, blinking in the final second.
func _gear_visible(time_left: float) -> bool:
	return time_left > 1.0 or (time_left > 0.0 and fmod(time_left, 0.2) < 0.12)

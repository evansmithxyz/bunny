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

# Owl (night only): fades out and back in on a loop, and can't be landed on
# while faded. Times are seconds within each cycle.
const OWL_CYCLE := 4.2
const OWL_FADE_OUT := [2.2, 2.7] # Start and end of fading out.
const OWL_FADE_IN := [3.6, 4.1]
const OWL_FAINT := 0.15 # Never fully invisible, so it's clear it'll come back.
const EAGLE_SWOOP := 70.0 # Eagles rise and dip this far as they cross.
const UFO_BOB := 8.0

# Art: body and wing drawn at 2x, facing right. "origin" is where the body's
# center sits in the body image, "pivot" is the wing's shoulder point in the
# wing image, and "shoulder" is where that attaches on the body (image pixels).
const ART_SCALE := 0.5
const ART := {
	"sparrow": {
		"body": preload("res://assets/art/sparrow_body.svg"), "origin": Vector2(130, 75),
		"wing": preload("res://assets/art/sparrow_wing.svg"), "pivot": Vector2(88, 26),
		"shoulder": Vector2(-4, -10),
	},
	"pigeon": {
		"body": preload("res://assets/art/pigeon_body.svg"), "origin": Vector2(165, 80),
		"wing": preload("res://assets/art/pigeon_wing.svg"), "pivot": Vector2(130, 34),
		"shoulder": Vector2(-8, -12),
	},
	"hummingbird": {
		"body": preload("res://assets/art/hummingbird_body.svg"), "origin": Vector2(95, 50),
		"wing": preload("res://assets/art/hummingbird_wing.svg"), "pivot": Vector2(72, 14),
		"shoulder": Vector2(-2, -14),
	},
	"crow": {
		"body": preload("res://assets/art/crow_body.svg"), "origin": Vector2(140, 75),
		"wing": preload("res://assets/art/crow_wing.svg"), "pivot": Vector2(102, 30),
		"shoulder": Vector2(-4, -10),
	},
	"goose": {
		"body": preload("res://assets/art/goose_body.svg"), "origin": Vector2(150, 130),
		"wing": preload("res://assets/art/goose_wing.svg"), "pivot": Vector2(122, 34),
		"shoulder": Vector2(-10, -12),
	},
	"owl": {
		"body": preload("res://assets/art/owl_body.svg"), "origin": Vector2(140, 80),
		"wing": preload("res://assets/art/owl_wing.svg"), "pivot": Vector2(118, 34),
		"shoulder": Vector2(-6, -12),
	},
	"eagle": {
		"body": preload("res://assets/art/eagle_body.svg"), "origin": Vector2(196, 52),
		"wing": preload("res://assets/art/eagle_wing.svg"), "pivot": Vector2(208, 42),
		"shoulder": Vector2(-8, -12),
	},
	"swallow": {
		"body": preload("res://assets/art/swallow_body.svg"), "origin": Vector2(98, 42),
		"wing": preload("res://assets/art/swallow_wing.svg"), "pivot": Vector2(96, 22),
		"shoulder": Vector2(-6, -12),
	},
	# Space zone: no wings. The bunny lands on the UFO's dome.
	"ufo": {"body": preload("res://assets/art/ufo.svg"), "origin": Vector2(126, 34), "wing": null},
	"satellite": {"body": preload("res://assets/art/satellite.svg"), "origin": Vector2(176, 44), "wing": null},
}

var kind := "sparrow"
var width := 90.0
var speed := 150.0
var direction := 1.0
var bounce_multiplier := 1.0
var flap_speed := 12.0
var flap_amount := 0.7 # Wing swing in radians either side of its middle angle.
var feather_color := Color("8a5a35") # Used for the feather burst on landing.
var screen_width := 720.0
var prev_top := 0.0 # top_y() before this frame's movement, for landing checks.

var _flap_time := 0.0
var _dip := 0.0 # Visual dip when landed on.
var _home_y := 0.0
var _dive_velocity := 0.0
var _diving := false
var _has_dived := false
var _time := 0.0
var _phase := 0.0 # Random offset so birds of a kind don't move in lockstep.


func setup(bird_kind: String, difficulty: float, screen_w: float) -> void:
	kind = bird_kind
	screen_width = screen_w
	match kind:
		"pigeon": # Big and slow: a safe landing.
			width = 130.0
			speed = 70.0
			bounce_multiplier = 0.95
			feather_color = Color("9aa3b5")
		"hummingbird": # Small and fast, but gives a super bounce.
			width = 56.0
			speed = 260.0
			bounce_multiplier = 1.45
			flap_speed = 45.0
			flap_amount = 0.5
			feather_color = Color("2fbf71")
		"crow": # Swoops away as you come down on it.
			width = 95.0
			speed = 130.0
			bounce_multiplier = 1.05
			feather_color = Color("2d2f3a")
		"goose": # Big, slow, and knocks you sideways when you land.
			width = 120.0
			speed = 90.0
			bounce_multiplier = 1.0
			flap_speed = 8.0
			feather_color = Color("f4f4f0")
		"owl": # Night only: fades in and out.
			width = 100.0
			speed = 100.0
			flap_speed = 7.0
			feather_color = Color("8a6f5a")
		"eagle": # Rare and fast, swoops up and down, big bounce if you catch it.
			width = 150.0
			speed = 300.0
			bounce_multiplier = 1.3
			flap_speed = 6.0
			flap_amount = 0.45
			feather_color = Color("5b3a29")
		"swallow": # Flies in V-shaped flocks.
			width = 56.0
			speed = 170.0
			flap_speed = 18.0
			feather_color = Color("2c3e70")
		"ufo": # Space zone: hovers and bobs; land on the dome.
			width = 120.0
			speed = 150.0
			bounce_multiplier = 1.15
			feather_color = Color("c9d3dd")
		"satellite": # Space zone: slow and steady.
			width = 140.0
			speed = 45.0
			feather_color = Color("e0a21b")
		_: # Sparrow
			width = 90.0
			speed = randf_range(120.0, 180.0)
	speed *= 1.0 + difficulty * 0.8
	direction = 1.0 if randf() < 0.5 else -1.0
	_flap_time = randf() * TAU
	_phase = randf() * TAU

func _ready() -> void:
	_home_y = position.y
	prev_top = top_y()


func step(delta: float, bunny: Bunny) -> void:
	prev_top = top_y()
	_time += delta
	var side_speed := speed
	match kind:
		"crow":
			_update_crow(delta, bunny)
			if _diving:
				side_speed *= CROW_DIVE_SIDE_BOOST
		"owl":
			modulate.a = _owl_alpha()
		"eagle":
			position.y = _home_y + EAGLE_SWOOP * sin(_time * 1.7 + _phase)
		"ufo":
			position.y = _home_y + UFO_BOB * sin(_time * 2.6 + _phase)

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


## How visible the owl is right now (1 = fully).
func _owl_alpha() -> float:
	var t := fmod(_time + _phase, OWL_CYCLE)
	if t < OWL_FADE_OUT[0]:
		return 1.0
	if t < OWL_FADE_OUT[1]:
		return lerpf(1.0, OWL_FAINT, inverse_lerp(OWL_FADE_OUT[0], OWL_FADE_OUT[1], t))
	if t < OWL_FADE_IN[0]:
		return OWL_FAINT
	if t < OWL_FADE_IN[1]:
		return lerpf(OWL_FAINT, 1.0, inverse_lerp(OWL_FADE_IN[0], OWL_FADE_IN[1], t))
	return 1.0


## False while an owl is faded out: the bunny falls straight through it.
func is_solid() -> bool:
	return kind != "owl" or modulate.a > 0.5


func top_y() -> float:
	return position.y - BODY_HALF_HEIGHT


func half_width() -> float:
	return width * 0.5


func hit() -> void:
	_dip = 16.0


func _draw() -> void:
	# Near an edge, also draw a copy on the other side so wrapping is seamless.
	var extent := width * 0.5 + 40.0 # Body plus head and beak.
	_draw_bird(Vector2(0, _dip))
	if position.x + extent > screen_width:
		_draw_bird(Vector2(-screen_width, _dip))
	if position.x - extent < 0.0:
		_draw_bird(Vector2(screen_width, _dip))


func _draw_bird(off: Vector2) -> void:
	var art: Dictionary = ART[kind]
	# Scale by -1 on x to face left; everything below is in the art's own pixels.
	var base := Transform2D(0.0, Vector2(direction * ART_SCALE, ART_SCALE), 0.0, off)
	draw_set_transform_matrix(base)
	draw_texture(art.body, -art.origin)

	if art.wing == null:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	# Wing rotates around the shoulder; positive angles raise it.
	var angle := 0.3 + flap_amount * sin(_flap_time)
	if _diving:
		angle = -0.15 # Wings tucked in for the swoop.
	draw_set_transform_matrix(base * Transform2D(angle, art.shoulder))
	draw_texture(art.wing, -art.pivot)
	draw_set_transform_matrix(Transform2D.IDENTITY)
extends Node2D
## Game manager: spawns birds, moves the camera up with the bunny, keeps score.

const Bunny := preload("res://scripts/bunny.gd")
const Bird := preload("res://scripts/bird.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Effects := preload("res://scripts/effects.gd")
const Scenery := preload("res://scripts/scenery.gd")

# Ground art (Kenney Jumper Pack colors and decorations).
const GRASS_TOP := Color("3bde80")
const GRASS := Color("2ecc71")
const GRASS_SHADOW := Color("28b162")
const DIRT := Color("d29353")
const GROUND_DECOR := [
	preload("res://assets/kenney/grass1.png"),
	preload("res://assets/kenney/grass2.png"),
	preload("res://assets/kenney/mushroom_red.png"),
	preload("res://assets/kenney/mushroom_brown.png"),
]

const SAVE_PATH := "user://save.cfg"
const GROUND_VISIBLE := 160.0 # How much ground shows at the start.
const MAX_DIFFICULTY_HEIGHT := 20000.0 # Height (pixels) where difficulty maxes out.

# Each new bird spawns within this horizontal distance of the bird below it
# (measured the short way around, since the screen wraps). The reach grows with
# difficulty; half the screen width (360) means "anywhere".
const BIRD_MIN_SPACING := 90.0
const BIRD_REACH_EASY := 240.0
const BIRD_REACH_HARD := 360.0

# Difficulty (0 to 1) at which tricky birds start appearing.
const CROW_START := 0.1 # Score 200
const GOOSE_START := 0.2 # Score 400
const GOOSE_KNOCK_SPEED := 900.0

# Landing on different birds in a row builds a combo; bouncing on the same bird
# again or touching the ground resets it.
const COMBO_MIN := 3
const COMBO_POINTS := 2 # Bonus per landing = combo * COMBO_POINTS

var screen_size: Vector2
var bunny: Bunny
var camera: Camera2D
var sfx: Sfx
var effects: Effects
var scenery: Scenery
var ground_decor: Array = [] # [texture, x, scale] for each tuft/mushroom.
var birds: Array = []
var next_bird_y := -160.0
var max_height := 0.0
var bonus_points := 0
var combo := 0
var last_bird_id := 0
var shake := 0.0
var best_score := 0
var game_over := false
var can_restart := false

var score_label: Label
var message_label: Label
var sky := Gradient.new()


func _ready() -> void:
	screen_size = get_viewport_rect().size
	_load_best()

	sky.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sky.colors = PackedColorArray([
		Color(0.53, 0.81, 0.98), # Day
		Color(0.98, 0.62, 0.5), # Sunset
		Color(0.06, 0.07, 0.2), # Night
	])

	sfx = Sfx.new()
	add_child(sfx)

	camera = Camera2D.new()
	camera.position = Vector2(screen_size.x / 2.0, -screen_size.y / 2.0 + GROUND_VISIBLE)
	add_child(camera)
	camera.make_current()

	scenery = Scenery.new()
	add_child(scenery)
	scenery.setup(screen_size, camera.position.y)
	_place_ground_decor()

	bunny = Bunny.new()
	bunny.screen_width = screen_size.x
	bunny.position = Vector2(screen_size.x / 2.0, -Bunny.FEET)
	bunny.z_index = 1
	add_child(bunny)

	effects = Effects.new()
	add_child(effects)

	_build_hud()
	_spawn_birds()
	scenery.update(0.0, camera.position.y, 0.0)
	_update_sky()

	message_label.text = "Tilt to steer!\nLand on birds to climb."
	message_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not game_over:
			message_label.visible = false)


func _process(delta: float) -> void:
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	shake = move_toward(shake, 0.0, 40.0 * delta)


func _physics_process(delta: float) -> void:
	if game_over:
		return
	screen_size = get_viewport_rect().size

	var prev_feet := bunny.position.y + Bunny.FEET
	bunny.step(delta)
	for bird in birds:
		bird.step(delta, bunny)
	_check_landing(prev_feet)

	_update_camera()
	_spawn_birds()
	_remove_offscreen_birds()
	scenery.update(delta, camera.position.y, _difficulty())

	max_height = maxf(max_height, -bunny.position.y)
	score_label.text = str(_score())
	_update_sky()

	if bunny.position.y - Bunny.FEET > camera.position.y + screen_size.y / 2.0:
		_end_game()


func _check_landing(prev_feet: float) -> void:
	if bunny.velocity.y <= 0.0:
		return # Only land while falling.
	var feet := bunny.position.y + Bunny.FEET

	if feet >= 0.0: # Ground
		bunny.position.y = -Bunny.FEET
		bunny.bounce()
		combo = 0
		sfx.play("thud")
		effects.dust(Vector2(bunny.position.x, 0))
		return

	for bird in birds:
		var dx := Bunny.wrapped_dx(bunny.position.x, bird.position.x, screen_size.x)
		var close_enough: bool = absf(dx) <= bird.half_width() + Bunny.HALF_WIDTH * 0.5
		# Use the bird's previous top too, so birds moving up/down can't slip past the feet.
		if prev_feet <= bird.prev_top and feet >= bird.top_y() and close_enough:
			_land_on_bird(bird)
			return


func _land_on_bird(bird: Bird) -> void:
	bunny.position.y = bird.top_y() - Bunny.FEET
	bunny.bounce(bird.bounce_multiplier)
	bird.hit()
	effects.feathers(Vector2(bunny.position.x, bird.top_y()), bird.feather_color)

	# Combo: different birds in a row.
	if bird.get_instance_id() == last_bird_id:
		combo = 1
	else:
		combo += 1
	last_bird_id = bird.get_instance_id()
	if combo >= COMBO_MIN:
		var points := combo * COMBO_POINTS
		bonus_points += points
		var color := Color(1.0, 0.9, 0.3) if combo < 10 else Color(1.0, 0.5, 0.9)
		effects.popup(bunny.position + Vector2(0, -70), "x%d  +%d" % [combo, points], color)
		if combo % 5 == 0:
			sfx.play("combo")

	# Boing rises in pitch as the combo grows.
	sfx.play("boing", 1.0 + 0.04 * mini(combo, 15))
	sfx.play("chirp", randf_range(0.9, 1.15))

	match bird.kind:
		"hummingbird":
			sfx.play("super")
			shake = 10.0
			effects.popup(bunny.position + Vector2(0, -120), "SUPER!", Color(0.5, 1.0, 0.7), 44)
		"goose":
			sfx.play("honk")
			shake = 6.0
			bunny.knock(bird.direction * GOOSE_KNOCK_SPEED, 0.35)


func _update_camera() -> void:
	# Only move up. Keep the bunny a little below center so you can see ahead.
	var target_y := bunny.position.y - screen_size.y * 0.1
	if target_y < camera.position.y:
		camera.position.y = target_y
	camera.position.x = screen_size.x / 2.0


func _spawn_birds() -> void:
	var top_of_view := camera.position.y - screen_size.y / 2.0
	while next_bird_y > top_of_view - 200.0:
		_spawn_bird(next_bird_y)
		var d := _difficulty()
		next_bird_y -= randf_range(lerpf(130.0, 200.0, d), lerpf(190.0, 280.0, d))


func _spawn_bird(y: float) -> void:
	var d := _difficulty()
	var bird := Bird.new()
	bird.setup(_pick_bird_kind(d), d, screen_size.x)
	var below: Bird = birds.back() if not birds.is_empty() else null
	if below:
		# Flying the same way as the bird below keeps them from drifting apart.
		if randf() < lerpf(0.5, 0.2, d):
			bird.direction = below.direction
		bird.position = Vector2(_reachable_x(below.position.x, d), y)
	else:
		bird.position = Vector2(randf_range(0.0, screen_size.x), y)
	if bird.kind == "crow":
		bird.dove.connect(sfx.play.bind("caw"))
	add_child(bird)
	birds.append(bird)


func _pick_bird_kind(d: float) -> String:
	var weights := {
		"sparrow": 1.0,
		"pigeon": lerpf(0.6, 0.15, d),
		"hummingbird": 0.2,
		"crow": 0.0 if d < CROW_START else lerpf(0.15, 0.45, d),
		"goose": 0.0 if d < GOOSE_START else lerpf(0.15, 0.3, d),
	}
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	var roll := randf() * total
	for kind: String in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return "sparrow"


func _reachable_x(from_x: float, difficulty: float) -> float:
	var reach := lerpf(BIRD_REACH_EASY, BIRD_REACH_HARD, difficulty)
	var offset := randf_range(BIRD_MIN_SPACING, reach) * (1.0 if randf() < 0.5 else -1.0)
	return fposmod(from_x + offset, screen_size.x)


func _remove_offscreen_birds() -> void:
	var bottom := camera.position.y + screen_size.y / 2.0 + 100.0
	for i in range(birds.size() - 1, -1, -1):
		if birds[i].position.y > bottom:
			birds[i].queue_free()
			birds.remove_at(i)


func _difficulty() -> float:
	return clampf(max_height / MAX_DIFFICULTY_HEIGHT, 0.0, 1.0)


func _score() -> int:
	return int(max_height / 10.0) + bonus_points


func _update_sky() -> void:
	RenderingServer.set_default_clear_color(sky.sample(_difficulty()))


func _end_game() -> void:
	game_over = true
	bunny.hurt = true
	bunny.queue_redraw()
	sfx.play("game_over")
	shake = 12.0
	var score := _score()
	var new_best := score > best_score
	if new_best:
		best_score = score
		_save_best()
	message_label.text = "Game Over\n\nScore: %d\nBest: %d%s\n\nTap to play again" % [
		score, best_score, "  NEW!" if new_best else ""]
	message_label.visible = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void: can_restart = true)


func _unhandled_input(event: InputEvent) -> void:
	if not can_restart:
		return
	var tapped := (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if tapped or event.is_action_pressed("ui_accept"):
		can_restart = false
		get_tree().reload_current_scene()


func _draw() -> void:
	# Ground: grass on top of dirt, drawn wider than the screen.
	var w := screen_size.x + 400.0
	draw_rect(Rect2(-200, 0, w, 2000), DIRT)
	draw_rect(Rect2(-200, 0, w, 30), GRASS)
	draw_rect(Rect2(-200, 0, w, 6), GRASS_TOP)
	draw_rect(Rect2(-200, 26, w, 6), GRASS_SHADOW)
	# Tufts and mushrooms standing on the grass.
	for decor in ground_decor:
		var tex: Texture2D = decor[0]
		var size: Vector2 = tex.get_size() * decor[2]
		draw_texture_rect(tex, Rect2(decor[1] - size.x / 2.0, 4.0 - size.y, size.x, size.y), false)


func _place_ground_decor() -> void:
	var x := randf_range(10.0, 60.0)
	while x < screen_size.x:
		ground_decor.append([GROUND_DECOR.pick_random(), x, randf_range(0.45, 0.7)])
		x += randf_range(70.0, 160.0)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	score_label = Label.new()
	score_label.position = Vector2(28, 60)
	_style_label(score_label, 52)
	score_label.text = "0"
	hud.add_child(score_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(message_label, 48)
	message_label.visible = false
	hud.add_child(message_label)


func _style_label(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 10)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("scores", "best", 0)


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save(SAVE_PATH)

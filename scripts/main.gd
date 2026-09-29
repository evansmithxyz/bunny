extends Node2D
## Game manager: spawns birds, moves the camera up with the bunny, keeps score.

const Bunny := preload("res://scripts/bunny.gd")
const Bird := preload("res://scripts/bird.gd")

const SAVE_PATH := "user://save.cfg"
const GROUND_VISIBLE := 160.0 # How much ground shows at the start.
const MAX_DIFFICULTY_HEIGHT := 20000.0 # Height (pixels) where difficulty maxes out.

# Each new bird spawns within this horizontal distance of the bird below it
# (measured the short way around, since the screen wraps). The reach grows with
# difficulty; half the screen width (360) means "anywhere".
const BIRD_MIN_SPACING := 90.0
const BIRD_REACH_EASY := 240.0
const BIRD_REACH_HARD := 360.0
const BIRD_EDGE_MARGIN := 50.0

var screen_size: Vector2
var bunny: Bunny
var camera: Camera2D
var birds: Array = []
var next_bird_y := -160.0
var max_height := 0.0
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

	camera = Camera2D.new()
	camera.position = Vector2(screen_size.x / 2.0, -screen_size.y / 2.0 + GROUND_VISIBLE)
	add_child(camera)
	camera.make_current()

	bunny = Bunny.new()
	bunny.screen_width = screen_size.x
	bunny.position = Vector2(screen_size.x / 2.0, -Bunny.FEET)
	bunny.z_index = 1
	add_child(bunny)

	_build_hud()
	_spawn_birds()
	_update_sky()

	message_label.text = "Tilt to steer!\nLand on birds to climb."
	message_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not game_over:
			message_label.visible = false)


func _physics_process(delta: float) -> void:
	if game_over:
		return
	screen_size = get_viewport_rect().size

	var prev_feet := bunny.position.y + Bunny.FEET
	bunny.step(delta)
	for bird in birds:
		bird.step(delta)
	_check_landing(prev_feet)

	_update_camera()
	_spawn_birds()
	_remove_offscreen_birds()

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
		return

	for bird in birds:
		var top: float = bird.top_y()
		var close_enough: bool = absf(bunny.position.x - bird.position.x) <= bird.half_width() + Bunny.HALF_WIDTH * 0.5
		if prev_feet <= top and feet >= top and close_enough:
			bunny.position.y = top - Bunny.FEET
			bunny.bounce(bird.bounce_multiplier)
			bird.hit()
			return


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
	var roll := randf()
	var kind := "sparrow"
	if roll < 0.12:
		kind = "hummingbird"
	elif roll < 0.12 + lerpf(0.35, 0.1, d):
		kind = "pigeon"

	var bird := Bird.new()
	bird.setup(kind, d, screen_size.x)
	var below: Bird = birds.back() if not birds.is_empty() else null
	if below:
		# Flying the same way as the bird below keeps them from drifting apart.
		if randf() < lerpf(0.5, 0.2, d):
			bird.direction = below.direction
		bird.position = Vector2(_reachable_x(below.position.x, d), y)
	else:
		bird.position = Vector2(randf_range(BIRD_EDGE_MARGIN, screen_size.x - BIRD_EDGE_MARGIN), y)
	add_child(bird)
	birds.append(bird)


func _reachable_x(from_x: float, difficulty: float) -> float:
	var reach := lerpf(BIRD_REACH_EASY, BIRD_REACH_HARD, difficulty)
	var offset := randf_range(BIRD_MIN_SPACING, reach) * (1.0 if randf() < 0.5 else -1.0)
	var x := fposmod(from_x + offset, screen_size.x)
	return clampf(x, BIRD_EDGE_MARGIN, screen_size.x - BIRD_EDGE_MARGIN)


func _remove_offscreen_birds() -> void:
	var bottom := camera.position.y + screen_size.y / 2.0 + 100.0
	for i in range(birds.size() - 1, -1, -1):
		if birds[i].position.y > bottom:
			birds[i].queue_free()
			birds.remove_at(i)


func _difficulty() -> float:
	return clampf(max_height / MAX_DIFFICULTY_HEIGHT, 0.0, 1.0)


func _score() -> int:
	return int(max_height / 10.0)


func _update_sky() -> void:
	RenderingServer.set_default_clear_color(sky.sample(_difficulty()))


func _end_game() -> void:
	game_over = true
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
	draw_rect(Rect2(-200, 0, screen_size.x + 400, 2000), Color(0.45, 0.3, 0.18))
	draw_rect(Rect2(-200, 0, screen_size.x + 400, 28), Color(0.35, 0.72, 0.3))


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

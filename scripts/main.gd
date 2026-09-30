extends Node2D
## Game manager: spawns birds, moves the camera up with the bunny, keeps score,
## and switches between the menu, playing, paused and game-over states.

const Bunny := preload("res://scripts/bunny.gd")
const Bird := preload("res://scripts/bird.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Effects := preload("res://scripts/effects.gd")
const Scenery := preload("res://scripts/scenery.gd")
const Hud := preload("res://scripts/hud.gd")

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

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
const MENU_BOUNCE := 0.6 # Smaller hops while the menu is showing.

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
var muted := false
var purple := false # Easter egg skin.
var state := State.MENU
var hud: Hud
var save := ConfigFile.new()
var sky := Gradient.new()

## Survives scene reloads: "Play again" reloads straight into a new game.
static var skip_menu := false


func _ready() -> void:
	screen_size = get_viewport_rect().size
	save.load(SAVE_PATH) # Missing on first launch; defaults below cover that.
	best_score = save.get_value("scores", "best", 0)
	muted = save.get_value("settings", "muted", false)
	purple = save.get_value("settings", "purple", false)
	AudioServer.set_bus_mute(0, muted)

	sky.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sky.colors = PackedColorArray([
		Color(0.53, 0.81, 0.98), # Day
		Color(0.98, 0.62, 0.5), # Sunset
		Color(0.06, 0.07, 0.2), # Night
	])

	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS # Button clicks play while paused.
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
	bunny.purple = purple
	add_child(bunny)

	effects = Effects.new()
	add_child(effects)

	hud = Hud.new()
	add_child(hud)
	hud.play_pressed.connect(_on_play_pressed)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.menu_pressed.connect(_go_to_menu)
	hud.sound_pressed.connect(_toggle_sound)
	hud.secret_found.connect(_toggle_purple)
	hud.set_muted(muted)
	hud.purple = purple

	_spawn_birds()
	scenery.update(0.0, camera.position.y, 0.0)
	_update_sky()

	if skip_menu:
		skip_menu = false
		_start_game()
	else:
		bunny.controls_enabled = false
		hud.show_menu(best_score)


func _process(delta: float) -> void:
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	shake = move_toward(shake, 0.0, 40.0 * delta)


func _physics_process(delta: float) -> void:
	if state == State.GAME_OVER:
		return
	screen_size = get_viewport_rect().size

	var prev_feet := bunny.position.y + Bunny.FEET
	bunny.step(delta)
	for bird in birds:
		bird.step(delta, bunny)
	_check_landing(prev_feet)
	if state == State.MENU:
		scenery.update(delta, camera.position.y, 0.0)
		return

	_update_camera()
	_spawn_birds()
	_remove_offscreen_birds()
	scenery.update(delta, camera.position.y, _difficulty())

	max_height = maxf(max_height, -bunny.position.y)
	hud.set_score(_score())
	_update_sky()

	if bunny.position.y - Bunny.FEET > camera.position.y + screen_size.y / 2.0:
		_end_game()


func _check_landing(prev_feet: float) -> void:
	if bunny.velocity.y <= 0.0:
		return # Only land while falling.
	var feet := bunny.position.y + Bunny.FEET

	if feet >= 0.0: # Ground
		bunny.position.y = -Bunny.FEET
		effects.dust(Vector2(bunny.position.x, 0))
		if state == State.MENU:
			bunny.bounce(MENU_BOUNCE) # Quiet little hops behind the menu.
			return
		bunny.bounce()
		combo = 0
		sfx.play("thud")
		return
	if state == State.MENU:
		return # On the menu the bunny only hops on the ground.

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
	state = State.GAME_OVER
	bunny.hurt = true
	bunny.queue_redraw()
	sfx.play("game_over")
	shake = 12.0
	var score := _score()
	var new_best := score > best_score
	if new_best:
		best_score = score
		_save_setting("scores", "best", best_score)
	hud.show_game_over(score, best_score, new_best)


# --- Menu, pause and sound --------------------------------------------------

func _start_game() -> void:
	state = State.PLAYING
	bunny.controls_enabled = true
	hud.show_playing()
	hud.set_score(_score())
	hud.show_hint("Tilt to steer!\nLand on birds to climb.", 3.0)


func _on_play_pressed() -> void:
	sfx.play("click")
	if state == State.MENU:
		_start_game()
	else: # "Play again" after a game over: fresh world, skip the menu.
		skip_menu = true
		get_tree().reload_current_scene()


func _pause() -> void:
	if state != State.PLAYING:
		return
	sfx.play("click")
	state = State.PAUSED
	get_tree().paused = true
	hud.show_paused()


func _resume() -> void:
	if state != State.PAUSED:
		return
	sfx.play("click")
	state = State.PLAYING
	get_tree().paused = false
	hud.show_playing()


func _go_to_menu() -> void:
	sfx.play("click")
	get_tree().paused = false
	skip_menu = false
	get_tree().reload_current_scene()


func _toggle_sound() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	hud.set_muted(muted)
	_save_setting("settings", "muted", muted)
	sfx.play("click") # Only heard when turning sound back on.


## Easter egg: tapping the menu title 7 times swaps the brown and purple bunnies.
func _toggle_purple() -> void:
	purple = not purple
	bunny.purple = purple
	hud.purple = purple
	_save_setting("settings", "purple", purple)
	sfx.play("super")
	var color := Color("b58bf0") if purple else Color("c68645")
	effects.feathers(bunny.position, color)
	effects.feathers(bunny.position + Vector2(0, -40), Color.WHITE)
	hud.show_toast("Purple bunny!" if purple else "Brown bunny is back!", 2.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_pause() # Switching apps or a phone call pauses the game.
		NOTIFICATION_WM_GO_BACK_REQUEST: # Android back button.
			match state:
				State.PLAYING:
					_pause()
				State.PAUSED:
					_resume()
				State.GAME_OVER:
					_go_to_menu()
				State.MENU:
					get_tree().quit()


func _save_setting(section: String, key: String, value: Variant) -> void:
	save.set_value(section, key, value)
	save.save(SAVE_PATH)


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

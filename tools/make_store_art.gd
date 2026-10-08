extends SceneTree
## Renders Google Play store art from the real game into store/:
##   screenshot_1..6.png   1080x1920 phone screenshots, each a staged moment
##                         from the game under a caption banner
##   feature_graphic.png   1024x500 banner
## Needs a window, so run WITHOUT --headless (audio off so it's silent):
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script tools/make_store_art.gd
## Uses a temporary save file for the shots and restores yours afterwards.

const OUT := "res://store/"
const SAVE := "user://save.cfg"
const BACKUP := "user://save.cfg.store_art_backup"
const Bunny := preload("res://scripts/bunny.gd")
const Bird := preload("res://scripts/bird.gd")
const Pickup := preload("res://scripts/pickup.gd")
const INK := Color("1f3b57")

# Final screenshot layout (1080x1920): caption at the top, the game below in a
# rounded white frame.
const SHOT_SIZE := Vector2i(1080, 1920)
const GAME_RECT := Rect2(107, 300, 866, 1540) # 9:16, same shape as the phone.
const FRAME := 10.0

var game_view: SubViewport # The game, rendered at 1080x1920 from its 720x1280 layout.
var caption_view: SubViewport # Caption + framed game image.
var caption_bg: TextureRect
var caption_label: Label
var game_image: TextureRect
var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BACKUP))
	game_view = SubViewport.new()
	game_view.size = SHOT_SIZE
	game_view.size_2d_override = Vector2i(720, 1280)
	game_view.size_2d_override_stretch = true
	game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(game_view)
	_build_caption_view()
	_run()


func _run() -> void:
	# 1. Daytime climb.
	_load_game({"carrots": 245, "best": 1830})
	await _frames(10)
	_start_playing()
	_stage(2400.0, Vector2(250, 900), Vector2(-120, -950))
	_bird("sparrow", Vector2(240, 1010), 1.0)
	_bird("pigeon", Vector2(540, 820), -1.0)
	_bird("hummingbird", Vector2(190, 600), 1.0)
	_bird("sparrow", Vector2(520, 400), -1.0)
	_bird("crow", Vector2(200, 230), 1.0)
	_bird("pigeon", Vector2(560, 1150), -1.0)
	for i in 4:
		_pickup("carrot", Vector2(540, 700 - i * 58))
	main.effects.feathers(_world(Vector2(240, 996)), Color("8a5a35"))
	main.effects.popup(_world(Vector2(250, 790)), "x6  +12", Color(1.0, 0.9, 0.3), 52)
	_hud(640, 7)
	await _shot(1, "Bounce on birds\nto climb the sky", Color("3b9bd6"))

	# 2. Sunset jetpack.
	_stage(9200.0, Vector2(360, 820), Vector2(60, -1500))
	main.bunny.jetpack_time = main.bunny.jetpack_duration * 0.92
	main.bunny.spring_bounces = 2
	main.bunny.redraw()
	_bird("sparrow", Vector2(140, 1080), 1.0)
	_bird("goose", Vector2(560, 1160), -1.0)
	_bird("crow", Vector2(590, 560), -1.0)
	_bird("hummingbird", Vector2(130, 420), 1.0)
	for i in 4:
		_pickup("gold_carrot" if i == 3 else "carrot", Vector2(380, 640 - i * 62))
	main.effects.popup(_world(Vector2(360, 710)), "JETPACK!", Color(0.6, 0.9, 1.0), 44)
	_hud(1180, 19)
	await _shot(2, "Grab power-ups\nlike jetpacks", Color("f39c34"))

	# 3. Night: owls, a swallow flock, stars.
	_stage(19000.0, Vector2(300, 1000), Vector2(-90, -950))
	_bird("owl", Vector2(560, 940), -1.0)
	_bird("owl", Vector2(230, 640), 1.0)
	_bird("sparrow", Vector2(150, 1130), 1.0)
	var flock := _bird("swallow", Vector2(470, 330), -1.0)
	for offset: Vector2 in main.FLOCK_OFFSETS.slice(1):
		_bird("swallow", Vector2(470 - offset.x, 330 + offset.y), -1.0, flock.speed)
	_hud(2350, 41)
	await _shot(3, "Owls come out\nat night", Color("5b3f8c"))

	# 4. Space.
	_stage(28500.0, Vector2(210, 820), Vector2(40, -1000))
	_bird("ufo", Vector2(200, 930), 1.0)
	_bird("satellite", Vector2(540, 1120), -1.0)
	_bird("satellite", Vector2(520, 690), -1.0)
	_bird("ufo", Vector2(180, 470), -1.0)
	for i in 3:
		_pickup("carrot", Vector2(370, 800 - i * 58))
	main.effects.popup(_world(Vector2(360, 560)), "SPACE!", Color(0.75, 0.85, 1.0), 60)
	_hud(3720, 66)
	await _shot(4, "Climb all the\nway to space!", Color("1d2150"))

	# 5. Shop: hats.
	_load_game({"carrots": 1240, "best": 4210, "color": "golden", "hat": "crown",
		"owned": ["golden", "crown", "party", "pink", "beanie", "helmet", "sparkles"]})
	await _frames(10)
	_clear_menu_world()
	main.bunny.visible = false
	main.hud.shop_pressed.emit()
	main.hud.shop._on_tab_pressed(1)
	await _shot(5, "Dress up\nyour bunny", Color("2ecc71"))

	# 6. Main menu.
	_load_game({"carrots": 245, "best": 1830, "hat": "party", "owned": ["party"]})
	await _frames(10)
	_clear_menu_world()
	main.bunny.position = _world(Vector2(600, 1040))
	main.bunny.velocity = Vector2(0, -500)
	main.bunny.redraw()
	_bird("sparrow", Vector2(95, 160), 1.0)
	_bird("hummingbird", Vector2(640, 110), -1.0)
	_bird("pigeon", Vector2(615, 482), -1.0)
	await _shot(6, "No ads. No account.\nJust hop!", Color("3b9bd6"))

	_build_feature_graphic()
	await _frames(10)
	var img: Image = (root.get_node("FeatureView") as SubViewport).get_texture().get_image()
	img.convert(Image.FORMAT_RGB8) # Play wants no transparency here.
	img.save_png(OUT + "feature_graphic.png")
	print("feature_graphic.png 1024x500")
	_restore_save()
	quit()


# --- Staging the game -----------------------------------------------------------

func _load_game(save: Dictionary) -> void:
	if main:
		main.queue_free()
	_write_save(save)
	main = load("res://scenes/main.tscn").instantiate()
	game_view.add_child(main)
	main.hud._test_start.visible = false # The testing shortcut doesn't belong in store art.


func _start_playing() -> void:
	main.hud.play_pressed.emit()
	main.hud._hint_label.visible = false
	main.set_physics_process(false) # Freeze the world; everything is placed by hand.


## Moves the game to `altitude` with an empty sky, and places the bunny
## (screen coordinates, 720x1280).
func _stage(altitude: float, bunny_at: Vector2, bunny_velocity: Vector2) -> void:
	_clear_world()
	main.max_height = altitude
	main.camera.position.y = -altitude
	main.next_bird_y = -altitude - 5000.0
	main.bunny.position = _world(bunny_at)
	main.bunny.velocity = bunny_velocity
	main.bunny.jetpack_time = 0.0
	main.bunny.spring_bounces = 0
	main.bunny.redraw()
	main._update_sky()
	main.scenery.update(0.0, main.camera.position.y, main._difficulty(), altitude)


## Freezes the menu's demo world and empties it, for placing things by hand.
func _clear_menu_world() -> void:
	main.set_physics_process(false)
	_clear_world()


func _clear_world() -> void:
	for list in [main.birds, main.pickups]:
		for node in list:
			node.queue_free()
		list.clear()
	for node in main.effects.get_children():
		node.queue_free()


func _world(screen: Vector2) -> Vector2:
	return Vector2(screen.x, main.camera.position.y + screen.y - 640.0)


func _bird(kind: String, at: Vector2, direction: float, speed: float = -1.0) -> Node:
	var bird := Bird.new()
	bird.setup(kind, 0.3, 720.0)
	bird.direction = direction
	if speed >= 0.0:
		bird.speed = speed
	bird.position = _world(at)
	bird._flap_time = randf_range(0.5, 1.5)
	main.add_child(bird)
	main.birds.append(bird)
	bird.queue_redraw()
	return bird


func _pickup(kind: String, at: Vector2) -> void:
	main._spawn_pickup(kind, _world(at))


func _hud(score: int, carrots: int) -> void:
	main.hud.set_score(score)
	main.hud.set_carrots(carrots)
	main.hud.set_powerups({
		"jetpack": main.bunny.jetpack_time / main.bunny.jetpack_duration,
		"wings": 0.0, "bubble": 0.0, "spring": float(main.bunny.spring_bounces), "slowmo": 0.0,
	})


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# --- Captioned screenshot -------------------------------------------------------

## Renders the game as it is now, puts it under `caption`, saves screenshot_N.
func _shot(number: int, caption: String, color: Color) -> void:
	await _frames(8)
	var game := game_view.get_texture().get_image()
	game_image.texture = ImageTexture.create_from_image(game)
	caption_label.text = caption
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, color.lightened(0.15))
	gradient.gradient.set_color(1, color.darkened(0.35))
	gradient.fill_to = Vector2(0, 1)
	gradient.width = 8
	gradient.height = 256
	caption_bg.texture = gradient
	await _frames(4)
	var img := caption_view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + "screenshot_%d.png" % number)
	print("screenshot_%d.png  %s" % [number, caption.replace("\n", " ")])


func _build_caption_view() -> void:
	caption_view = SubViewport.new()
	caption_view.size = SHOT_SIZE
	caption_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(caption_view)

	caption_bg = TextureRect.new()
	caption_bg.size = Vector2(SHOT_SIZE)
	caption_bg.stretch_mode = TextureRect.STRETCH_SCALE
	caption_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	caption_view.add_child(caption_bg)

	caption_label = Label.new()
	caption_label.position = Vector2(40, 20)
	caption_label.size = Vector2(1000, GAME_RECT.position.y - 30)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 84)
	caption_label.add_theme_color_override("font_color", Color.WHITE)
	caption_label.add_theme_color_override("font_outline_color", INK)
	caption_label.add_theme_constant_override("outline_size", 20)
	caption_label.add_theme_constant_override("line_spacing", -8)
	caption_view.add_child(caption_label)

	# White rounded frame with a soft shadow, and the game clipped to its corners.
	var frame := Panel.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.WHITE
	frame_style.set_corner_radius_all(56)
	frame_style.shadow_color = Color(0, 0, 0, 0.3)
	frame_style.shadow_size = 24
	frame_style.shadow_offset = Vector2(0, 10)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = GAME_RECT.position - Vector2(FRAME, FRAME)
	frame.size = GAME_RECT.size + Vector2(FRAME, FRAME) * 2.0
	caption_view.add_child(frame)
	var clip := Panel.new()
	var clip_style := StyleBoxFlat.new()
	clip_style.bg_color = Color.WHITE
	clip_style.set_corner_radius_all(46)
	clip.add_theme_stylebox_override("panel", clip_style)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.position = Vector2(FRAME, FRAME)
	clip.size = GAME_RECT.size
	frame.add_child(clip)
	game_image = TextureRect.new()
	game_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_image.stretch_mode = TextureRect.STRETCH_SCALE
	game_image.size = GAME_RECT.size
	clip.add_child(game_image)


# --- Feature graphic ------------------------------------------------------------

## 1024x500 banner: title on the left, bunny bouncing off a bird on the right.
func _build_feature_graphic() -> void:
	var view := SubViewport.new()
	view.name = "FeatureView"
	view.size = Vector2i(1024, 500)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	var sky := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gradient.gradient.colors = PackedColorArray([Color(0.45, 0.76, 0.97), Color(0.7, 0.88, 0.99), Color(1.0, 0.89, 0.66)])
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(0, 1)
	gradient.width = 16
	gradient.height = 500
	sky.texture = gradient
	sky.size = Vector2(1024, 500)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	view.add_child(sky)

	var hills := Sprite2D.new()
	hills.texture = preload("res://assets/kenney/bg_layer4.png")
	hills.centered = false
	hills.scale = Vector2(0.5, 0.5)
	hills.position = Vector2(0, 500 - 1024 + 40)
	view.add_child(hills)
	for c in [[Vector2(120, 70), 0.55], [Vector2(560, 50), 0.4], [Vector2(900, 380), 0.5]]:
		var cloud := Sprite2D.new()
		cloud.texture = preload("res://assets/art/cloud.svg")
		cloud.position = c[0]
		cloud.scale = Vector2.ONE * c[1]
		view.add_child(cloud)

	var world := Node2D.new()
	view.add_child(world)
	var birds := [["pigeon", Vector2(905, 120), -1.0, 0.9], ["hummingbird", Vector2(620, 300), 1.0, 1.2], ["sparrow", Vector2(770, 420), 1.0, 1.6]]
	for spec in birds:
		var bird := Bird.new()
		bird.setup(spec[0], 0.0, 100000.0)
		bird.direction = spec[2]
		bird.position = spec[1]
		bird.scale = Vector2.ONE * spec[3]
		bird._flap_time = 1.2
		world.add_child(bird)
	var bunny := Bunny.new()
	bunny.screen_width = 100000.0
	bunny.position = Vector2(770, 250)
	bunny.scale = Vector2(1.6, 1.6)
	bunny.velocity = Vector2(120, -900) # Jumping pose, leaning a little.
	world.add_child(bunny)
	bunny.redraw()
	for i in 3:
		var carrot := Pickup.new()
		carrot.kind = "gold_carrot" if i == 2 else "carrot"
		carrot.position = Vector2(640, 205 - i * 72)
		carrot.scale = Vector2(1.3, 1.3)
		world.add_child(carrot)

	var title := Label.new()
	title.text = "Bunny\nHop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 28)
	title.add_theme_constant_override("line_spacing", -36)
	title.position = Vector2(30, 40)
	title.size = Vector2(500, 420)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view.add_child(title)


# --- Temporary save -------------------------------------------------------------

func _write_save(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "carrots", values.get("carrots", 0))
	cfg.set_value("scores", "best", values.get("best", 0))
	cfg.set_value("shop", "color", values.get("color", "brown"))
	cfg.set_value("shop", "hat", values.get("hat", "none"))
	cfg.set_value("shop", "owned", values.get("owned", []))
	cfg.save(SAVE)


func _restore_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(SAVE))

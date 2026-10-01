extends SceneTree
## Renders Google Play store art from the real game into store/:
##   feature_graphic.png   1024x500 banner
##   screenshot_1..4.png   1080x1920 phone screenshots
## Needs a window, so run WITHOUT --headless (audio off so it's silent):
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script tools/make_store_art.gd
## Uses a temporary save file for the shop/menu shots and restores yours after.

const OUT := "res://store/"
const SAVE := "user://save.cfg"
const BACKUP := "user://save.cfg.store_art_backup"
const Bunny := preload("res://scripts/bunny.gd")
const Bird := preload("res://scripts/bird.gd")
const Pickup := preload("res://scripts/pickup.gd")
const INK := Color("1f3b57")

var shot_view: SubViewport # Phone-sized, 1080x1920 drawn from a 720x1280 game.
var main: Node
var step := 0
var wait := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BACKUP))
	_write_save({"carrots": 245, "best": 1830, "color": "brown", "hat": "party", "owned": ["party"]})

	shot_view = SubViewport.new()
	shot_view.size = Vector2i(1080, 1920)
	shot_view.size_2d_override = Vector2i(720, 1280)
	shot_view.size_2d_override_stretch = true
	shot_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(shot_view)
	_load_game()
	physics_frame.connect(_tick)


func _tick() -> void:
	if wait > 0:
		wait -= 1
		return
	step += 1
	match step:
		1: # Main menu with a party hat.
			_after(90)
		2:
			_save_shot("screenshot_1.png")
			main.hud.play_pressed.emit()
			main.hud._hint_label.visible = false
			_after(1)
		3: # Daytime climb: steer onto birds for a while to build a combo.
			wait = 1000000 # Paused until the autopilot finishes.
			_autopilot(420)
		4:
			_save_shot("screenshot_2.png")
			# Sunset jetpack flight through carrots.
			main.max_height = 9500.0
			main.bunny.jetpack_time = main.bunny.jetpack_duration
			_after(40)
		5:
			# Clear the sky's own pickups so nothing else pops up over the bunny,
			# then lay a carrot trail just ahead of the jetpack.
			for p in main.pickups:
				p.queue_free()
			main.pickups.clear()
			for i in 5:
				main._spawn_pickup("carrot", main.bunny.position + Vector2(0, -150 - i * 60))
			main._spawn_pickup("gold_carrot", main.bunny.position + Vector2(0, -150 - 5 * 60))
			_after(5) # One or two collected, the rest still ahead.
		6:
			_save_shot("screenshot_3.png")
			main.queue_free()
			_write_save({"carrots": 520, "best": 4210, "color": "golden", "hat": "crown",
				"owned": ["golden", "crown", "party", "pink"], "level_jetpack": 2})
			_load_game()
			_after(10)
		7: # Shop, hats tab.
			main.hud.shop_pressed.emit()
			main.hud.shop._on_tab_pressed(1)
			_after(20)
		8:
			_save_shot("screenshot_4.png")
			main.queue_free()
			_build_feature_graphic()
			_after(10)
		9:
			var img: Image = (root.get_node("FeatureView") as SubViewport).get_texture().get_image()
			img.convert(Image.FORMAT_RGB8) # Play wants no transparency here.
			img.save_png(OUT + "feature_graphic.png")
			print("feature_graphic.png 1024x500")
			_restore_save()
			quit()


func _after(frames: int) -> void:
	wait = frames


## Plays for a while, steering onto the bird below whenever falling.
func _autopilot(frames: int) -> void:
	for i in frames:
		await physics_frame
		var b = main.bunny
		if b.velocity.y > 0.0:
			var best = null
			for bird in main.birds:
				if bird.top_y() >= b.position.y + Bunny.FEET and (best == null or bird.top_y() < best.top_y()):
					best = bird
			if best:
				b.position.x = best.position.x
	# Stop just after a bounce so the bunny is mid-leap with a combo popup.
	while main.bunny.velocity.y > -700.0:
		await physics_frame
		var b = main.bunny
		if b.velocity.y > 0.0:
			for bird in main.birds:
				if bird.top_y() >= b.position.y + Bunny.FEET:
					b.position.x = bird.position.x
					break
	for i in 6:
		await physics_frame
	wait = 0 # Continue with step 4 on the next tick.


func _load_game() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	shot_view.add_child(main)


func _save_shot(file: String) -> void:
	var img := shot_view.get_texture().get_image()
	img.save_png(OUT + file)
	print("%s %dx%d" % [file, img.get_width(), img.get_height()])


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
	for i in 4:
		var carrot := Pickup.new()
		carrot.kind = "gold_carrot" if i == 3 else "carrot"
		carrot.position = Vector2(630 - i * 40, 190 - i * 34)
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


func _write_save(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "carrots", values.carrots)
	cfg.set_value("scores", "best", values.best)
	cfg.set_value("shop", "color", values.color)
	cfg.set_value("shop", "hat", values.hat)
	cfg.set_value("shop", "owned", values.owned)
	if values.has("level_jetpack"):
		cfg.set_value("shop", "level_jetpack", values.level_jetpack)
	cfg.save(SAVE)


func _restore_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(SAVE))

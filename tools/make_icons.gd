extends SceneTree
## Generates the app icons and the boot splash from the game's art.
## Needs a window (for drawing the title text), so run it WITHOUT --headless:
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --script tools/make_icons.gd
##
## Writes to assets/icon/:
##   icon_192.png        classic square icon, also the project/window icon
##   icon_background.png Android adaptive icon layers (432x432). Launchers
##   icon_foreground.png crop these to their own shape, so the bunny stays
##   icon_monochrome.png inside the central safe circle.
##   splash_icon.png     Android 12+ launch screen icon
## and store/icon_512.png, the Google Play listing icon.
##   splash.png          Godot boot splash (720x1280, like the game's start)

const OUT := "res://assets/icon/"
const BUNNY := "res://assets/kenney/bunny1_stand.png"
const CLOUD := "res://assets/art/cloud.svg"
const SKY_TOP := Color(0.45, 0.76, 0.97)
const SKY := Color(0.53, 0.81, 0.98) # Matches the game's daytime sky.
const GRASS_TOP := Color("3bde80")
const GRASS := Color("2ecc71")
const GRASS_SHADOW := Color("28b162")
const DIRT := Color("d29353")
const INK := Color("1f3b57")

var frames := 0
var viewport: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bunny := _load_image(BUNNY)

	# Adaptive icon layers, 432x432. Visible area is roughly the middle 288px circle.
	var layers := _icon_layers(bunny, 432)
	_save(layers[0], "icon_background.png")
	_save(layers[1], "icon_foreground.png")
	var monochrome := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	_place_bunny(monochrome, _silhouette(bunny), 200, Vector2i(216, 330))
	_save(monochrome, "icon_monochrome.png")

	# Full icon = background + foreground, used for the classic icon and splash icon.
	var full := _flatten(layers)
	_save(full, "splash_icon.png")
	# Store icon goes to store/ (ignored by Godot) so it isn't packed into the game.
	var store_icon := _flatten(_icon_layers(bunny, 512)) # Drawn at size, not upscaled.
	print("store/icon_512.png: ", error_string(store_icon.save_png("res://store/icon_512.png")))
	var classic := full.duplicate()
	classic.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	_round_corners(classic, 36)
	_save(classic, "icon_192.png")

	_build_splash_scene(bunny)
	process_frame.connect(_capture_splash)


## [background, foreground] icon layers at `size` pixels (the design is 432).
func _icon_layers(bunny: Image, size: int) -> Array[Image]:
	var s := size / 432.0
	var background := _sky_with_ground(size, int(318 * s))
	var cloud := Image.new()
	cloud.load_svg_from_string(FileAccess.get_file_as_string(CLOUD), 0.5 * s)
	background.blend_rect(cloud, Rect2i(Vector2i.ZERO, cloud.get_size()), Vector2i(int(70 * s), int(120 * s)))
	var foreground := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	_place_bunny(foreground, bunny, int(200 * s), Vector2i(size / 2, int(330 * s)))
	return [background, foreground]


func _flatten(layers: Array[Image]) -> Image:
	var img := layers[0].duplicate()
	img.blend_rect(layers[1], Rect2i(Vector2i.ZERO, layers[1].get_size()), Vector2i.ZERO)
	return img


func _capture_splash() -> void:
	frames += 1
	if frames == 5: # Give the viewport a few frames to draw.
		var img := viewport.get_texture().get_image()
		_save(img, "splash.png")
		quit()


## Lays out the splash like the game's first view: title, bunny on the grass.
func _build_splash_scene(bunny: Image) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var sky := TextureRect.new()
	sky.texture = ImageTexture.create_from_image(_sky_with_ground(720, 1120, 1280))
	viewport.add_child(sky)

	var bunny_rect := TextureRect.new()
	var big := bunny.duplicate()
	big.resize(144, 241, Image.INTERPOLATE_LANCZOS)
	bunny_rect.texture = ImageTexture.create_from_image(big)
	bunny_rect.position = Vector2(360 - 72, 1124 - 241)
	viewport.add_child(bunny_rect)

	var title := Label.new()
	title.text = "Bunny\nHop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 26)
	title.add_theme_constant_override("line_spacing", -34)
	title.position = Vector2(0, 250)
	title.size = Vector2(720, 400)
	viewport.add_child(title)


## Vertical sky gradient with the game's grass and dirt starting at `ground_y`.
func _sky_with_ground(width: int, ground_y: int, height: int = -1) -> Image:
	if height < 0:
		height = width
	var img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var color := SKY_TOP.lerp(SKY, float(y) / ground_y)
		if y >= ground_y:
			var depth := y - ground_y
			if depth < 8:
				color = GRASS_TOP
			elif depth < 26:
				color = GRASS
			elif depth < 32:
				color = GRASS_SHADOW
			else:
				color = DIRT
		img.fill_rect(Rect2i(0, y, width, 1), color)
	return img


## Scales the bunny to `height` pixels tall and stands its feet at `feet`.
func _place_bunny(canvas: Image, bunny: Image, height: int, feet: Vector2i) -> void:
	var scaled := bunny.duplicate()
	var width := int(bunny.get_width() * float(height) / bunny.get_height())
	scaled.resize(width, height, Image.INTERPOLATE_LANCZOS)
	canvas.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), feet - Vector2i(width / 2, height))


## Solid white in the bunny's shape, for Android's themed (single-color) icons.
func _silhouette(bunny: Image) -> Image:
	var img := bunny.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, Color(1, 1, 1, img.get_pixel(x, y).a))
	return img


func _round_corners(img: Image, radius: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var cx := clampi(x, radius, w - radius - 1)
			var cy := clampi(y, radius, h - radius - 1)
			var d := Vector2(x - cx, y - cy).length()
			if d > radius - 1:
				var c := img.get_pixel(x, y)
				c.a *= clampf(radius - d, 0.0, 1.0) # Soft edge.
				img.set_pixel(x, y, c)


func _load_image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT + file)
	print("%s %dx%d: %s" % [file, img.get_width(), img.get_height(), error_string(err)])

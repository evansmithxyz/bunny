extends Node2D
## Background scenery: hills by the ground (with parallax), drifting clouds,
## and higher up, twinkling stars and a ringed planet in space.

const HILLS_FAR := preload("res://assets/kenney/bg_layer3.png")
const HILLS_NEAR := preload("res://assets/kenney/bg_layer4.png")
const CLOUD := preload("res://assets/art/cloud.svg")
const PLANET := preload("res://assets/art/planet.svg")

# Altitudes (pixels climbed) where things fade in and out.
const STARS_FROM := 12000.0 # Dusk: first stars.
const STARS_FULL := 19000.0 # Night: all stars.
const CLOUD_CEILING := 21000.0 # No new clouds above this...
const CLOUDS_GONE := 23000.0 # ...and existing ones have faded out by here.
const PLANET_FROM := 23000.0
const PLANET_FULL := 27000.0
const PLANET_SINK_DISTANCE := 40000.0 # Climb this far past PLANET_FROM to sink it fully.
const STAR_COUNT := 90
const STAR_SCROLL := 0.05 # Stars drift down slowly as you climb (they're far away).

const HILLS_SCALE := 0.36
# How much of the camera's climb each hill layer follows. Farther layers follow
# more, so they scroll away more slowly (parallax).
const HILLS_FOLLOW := [0.6, 0.35]
const HILLS_LIFT := [-40.0, 25.0] # Far hills sit a bit higher than near ones.

const CLOUD_GAP_MIN := 350.0
const CLOUD_GAP_MAX := 650.0
const CLOUD_MARGIN := 130.0 # Clouds wrap once fully off-screen.

var screen_size: Vector2

var _start_camera_y := 0.0
var _hills: Array[Sprite2D] = []
var _clouds: Array[Sprite2D] = []
var _cloud_speeds: Array[float] = []
var _next_cloud_y := -250.0
var _sky_layer: CanvasLayer # Behind the world: stars and the planet.
var _star_field: Node2D
var _stars: Array[Vector4] = [] # x, y, size, twinkle phase
var _star_alpha := 0.0
var _star_scroll := 0.0
var _planet: Sprite2D
var _time := 0.0


func setup(size: Vector2, camera_y: float) -> void:
	screen_size = size
	_start_camera_y = camera_y
	for tex: Texture2D in [HILLS_FAR, HILLS_NEAR]:
		var hill := Sprite2D.new()
		hill.texture = tex
		hill.centered = false
		hill.scale = Vector2.ONE * HILLS_SCALE
		hill.z_index = -3 + _hills.size()
		add_child(hill)
		_hills.append(hill)

	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -1
	add_child(_sky_layer)
	_planet = Sprite2D.new()
	_planet.texture = PLANET
	_planet.scale = Vector2(0.75, 0.75)
	_planet.modulate.a = 0.0
	_sky_layer.add_child(_planet)
	_star_field = Node2D.new()
	_star_field.draw.connect(_draw_stars)
	_sky_layer.add_child(_star_field)
	for i in STAR_COUNT:
		_stars.append(Vector4(randf() * size.x, randf() * size.y, randf_range(1.0, 3.2), randf() * TAU))


## `altitude` is how high the bunny has climbed (pixels), for stars and space.
func update(delta: float, camera_y: float, difficulty: float, altitude: float = 0.0) -> void:
	_time += delta
	var climbed := camera_y - _start_camera_y # Negative as the camera rises.
	_update_sky(camera_y, altitude)
	for i in _hills.size():
		var size := _hills[i].texture.get_size() * HILLS_SCALE
		_hills[i].position = Vector2(
			(screen_size.x - size.x) / 2.0,
			HILLS_LIFT[i] - size.y + climbed * HILLS_FOLLOW[i])

	var top := camera_y - screen_size.y / 2.0
	while _next_cloud_y > top - 300.0:
		if -_next_cloud_y < CLOUD_CEILING: # No clouds in space.
			_spawn_cloud(_next_cloud_y)
		_next_cloud_y -= randf_range(CLOUD_GAP_MIN, CLOUD_GAP_MAX)

	var bottom := camera_y + screen_size.y / 2.0 + 200.0
	# Fade out toward night, and away completely leaving the atmosphere.
	var alpha := lerpf(0.9, 0.25, difficulty) * (1.0 - smoothstep(CLOUD_CEILING, CLOUDS_GONE, altitude))
	for i in range(_clouds.size() - 1, -1, -1):
		var cloud := _clouds[i]
		if cloud.position.y > bottom:
			cloud.queue_free()
			_clouds.remove_at(i)
			_cloud_speeds.remove_at(i)
			continue
		cloud.position.x += _cloud_speeds[i] * delta
		if cloud.position.x > screen_size.x + CLOUD_MARGIN:
			cloud.position.x = -CLOUD_MARGIN
		elif cloud.position.x < -CLOUD_MARGIN:
			cloud.position.x = screen_size.x + CLOUD_MARGIN
		cloud.modulate.a = alpha


func _spawn_cloud(y: float) -> void:
	var cloud := Sprite2D.new()
	cloud.texture = CLOUD
	cloud.scale = Vector2.ONE * randf_range(0.4, 0.75)
	cloud.position = Vector2(randf_range(0.0, screen_size.x), y)
	cloud.z_index = -1
	add_child(cloud)
	_clouds.append(cloud)
	_cloud_speeds.append(randf_range(8.0, 25.0) * (1.0 if randf() < 0.5 else -1.0))


func _update_sky(camera_y: float, altitude: float) -> void:
	var size := get_viewport_rect().size
	_star_alpha = smoothstep(STARS_FROM, STARS_FULL, altitude)
	_star_scroll = -camera_y * STAR_SCROLL
	_star_field.visible = _star_alpha > 0.0
	if _star_field.visible:
		_star_field.queue_redraw()
	_planet.modulate.a = smoothstep(PLANET_FROM, PLANET_FULL, altitude) * 0.85
	_planet.visible = _planet.modulate.a > 0.0
	# Far away, so it barely moves: it slowly sinks as you keep climbing, then stays.
	var sink := clampf((altitude - PLANET_FROM) / PLANET_SINK_DISTANCE, 0.0, 1.0)
	_planet.position = Vector2(size.x * 0.7, lerpf(size.y * 0.2, size.y * 0.62, sink))


func _draw_stars() -> void:
	var size := get_viewport_rect().size
	for star in _stars:
		var y := fposmod(star.y + _star_scroll, size.y)
		var twinkle := 0.55 + 0.45 * sin(_time * (1.5 + star.w) + star.w * 7.0)
		var color := Color(1.0, 0.97, 0.88, _star_alpha * twinkle)
		_star_field.draw_circle(Vector2(star.x, y), star.z, color)
		if star.z > 2.6: # The biggest stars get a little cross-shaped sparkle.
			var spark := Color(color, color.a * 0.6)
			_star_field.draw_line(Vector2(star.x - 7, y), Vector2(star.x + 7, y), spark, 1.5)
			_star_field.draw_line(Vector2(star.x, y - 7), Vector2(star.x, y + 7), spark, 1.5)

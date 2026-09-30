extends Node2D
## Background scenery: hills by the ground (with parallax) and drifting clouds.

const HILLS_FAR := preload("res://assets/kenney/bg_layer3.png")
const HILLS_NEAR := preload("res://assets/kenney/bg_layer4.png")
const CLOUD := preload("res://assets/art/cloud.svg")

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


func update(delta: float, camera_y: float, difficulty: float) -> void:
	var climbed := camera_y - _start_camera_y # Negative as the camera rises.
	for i in _hills.size():
		var size := _hills[i].texture.get_size() * HILLS_SCALE
		_hills[i].position = Vector2(
			(screen_size.x - size.x) / 2.0,
			HILLS_LIFT[i] - size.y + climbed * HILLS_FOLLOW[i])

	var top := camera_y - screen_size.y / 2.0
	while _next_cloud_y > top - 300.0:
		_spawn_cloud(_next_cloud_y)
		_next_cloud_y -= randf_range(CLOUD_GAP_MIN, CLOUD_GAP_MAX)

	var bottom := camera_y + screen_size.y / 2.0 + 200.0
	var alpha := lerpf(0.9, 0.25, difficulty) # Fade out toward night.
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

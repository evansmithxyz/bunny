extends Control
## Tilt controls: a live test track, "Set center" so any holding angle works
## (lying down, leaning back...), and a sensitivity slider. Reports changes
## to main.gd through signals; main.gd saves them.

signal closed
signal center_set(right: Vector3) # Vector3.RIGHT means the default (upright).
signal sensitivity_changed(value: float)

const UI := preload("res://scripts/ui.gd")
const Bunny := preload("res://scripts/bunny.gd")
const BUNNY_ICON := preload("res://assets/kenney/bunny1_stand.png")
const KNOB := preload("res://assets/ui/slider_knob.svg")

const SENSITIVITY_MIN := 0.5
const SENSITIVITY_MAX := 1.8
const TRACK_WIDTH := 480.0
const MARKER_SIZE := Vector2(48, 80)

## Where tilt readings come from. Tests swap in fake readings.
var read_accel := Callable(Input, "get_accelerometer")

var _right := Vector3.RIGHT
var _sensitivity := 1.0
var _marker: TextureRect
var _status: Label
var _slider: HSlider
var _status_id := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UI.card(center, 40, 20)

	card.add_child(UI.label("Tilt controls", 56, UI.INK))
	var hint := UI.label("Hold your phone the way you like to play, then tap Set center.", 28, Color("5d7185"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = TRACK_WIDTH
	card.add_child(hint)

	card.add_child(_build_track())
	_status = UI.label("", 28, UI.ORANGE[1])
	# Wraps within the card and keeps room for two lines so the card doesn't resize.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(TRACK_WIDTH, 76)
	card.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var set_center := UI.button("Set center", null, UI.ORANGE, Vector2(0, 96), 38)
	set_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_center.pressed.connect(_on_set_center)
	buttons.add_child(set_center)
	var reset := UI.button("Reset", null, UI.BLUE, Vector2(170, 96), 38)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	card.add_child(buttons)

	card.add_child(UI.spacer(4))
	card.add_child(UI.label("Sensitivity", 32, UI.INK))
	card.add_child(_build_slider())
	card.add_child(UI.spacer(4))

	var done := UI.button("Done", null, UI.BLUE, Vector2(0, 96))
	done.pressed.connect(closed.emit)
	card.add_child(done)


## Shows the screen with the player's current settings.
func open(right: Vector3, sensitivity: float) -> void:
	_right = right
	_sensitivity = sensitivity
	_slider.set_value_no_signal(sensitivity)
	_say("" if _has_sensor() else "No tilt sensor found. Use the arrow keys.")


func _process(_delta: float) -> void:
	if not visible:
		return
	# Slide the little bunny along the track exactly as the game would steer.
	var steer := Bunny.steer(Bunny.tilt_amount(read_accel.call(), _right), _sensitivity)
	var travel := (TRACK_WIDTH - MARKER_SIZE.x) / 2.0
	_marker.position.x = travel + steer * travel


func _on_set_center() -> void:
	if not _has_sensor():
		_say("No tilt sensor found. Use the arrow keys.")
		return
	_right = Bunny.calibrate_right(read_accel.call())
	center_set.emit(_right)
	_say("Centered! The bunny should sit still in the middle.")


func _on_reset() -> void:
	_right = Vector3.RIGHT
	center_set.emit(_right)
	_say("Back to normal (phone held upright).")


func _has_sensor() -> bool:
	return (read_accel.call() as Vector3).length() > 0.1


func _say(text: String) -> void:
	_status.text = text
	_status_id += 1
	var id := _status_id
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if id == _status_id and _has_sensor():
			_status.text = "")


## A rounded track with a center mark and a little bunny that follows the tilt.
func _build_track() -> Control:
	var area := Control.new()
	area.custom_minimum_size = Vector2(TRACK_WIDTH, MARKER_SIZE.y + 10)
	var bar := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.1)
	style.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("panel", style)
	bar.position = Vector2(0, MARKER_SIZE.y - 6)
	bar.size = Vector2(TRACK_WIDTH, 18)
	area.add_child(bar)
	var mark := ColorRect.new()
	mark.color = UI.ORANGE[1]
	mark.position = Vector2(TRACK_WIDTH / 2.0 - 2.0, MARKER_SIZE.y - 14)
	mark.size = Vector2(4, 34)
	area.add_child(mark)
	_marker = TextureRect.new()
	_marker.texture = BUNNY_ICON
	_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_marker.size = MARKER_SIZE
	_marker.position = Vector2((TRACK_WIDTH - MARKER_SIZE.x) / 2.0, 0)
	area.add_child(_marker)
	return area


func _build_slider() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UI.label("Low", 26, Color("5d7185")))
	_slider = HSlider.new()
	_slider.min_value = SENSITIVITY_MIN
	_slider.max_value = SENSITIVITY_MAX
	_slider.step = 0.05
	_slider.value = 1.0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.add_theme_icon_override("grabber", KNOB)
	_slider.add_theme_icon_override("grabber_highlight", KNOB)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0, 0, 0, 0.12)
	groove.set_corner_radius_all(7)
	groove.content_margin_top = 7
	groove.content_margin_bottom = 7
	var filled := StyleBoxFlat.new()
	filled.bg_color = UI.ORANGE[0]
	filled.set_corner_radius_all(7)
	filled.content_margin_top = 7
	filled.content_margin_bottom = 7
	_slider.add_theme_stylebox_override("slider", groove)
	_slider.add_theme_stylebox_override("grabber_area", filled)
	_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	_slider.value_changed.connect(func(value: float) -> void:
		_sensitivity = value
		sensitivity_changed.emit(value))
	row.add_child(_slider)
	row.add_child(UI.label("High", 26, Color("5d7185")))
	return row

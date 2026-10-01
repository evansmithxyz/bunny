extends CanvasLayer
## All on-screen UI: the score, the pause button, and the menu, pause and
## game-over screens. It only reports button presses through signals; main.gd
## decides what they do. Keeps running while the game is paused.

signal play_pressed
signal pause_pressed
signal resume_pressed
signal menu_pressed
signal sound_pressed
signal music_pressed
signal vibration_pressed
signal secret_found # Title tapped SECRET_TAPS times in a row.

const ICON_PLAY := preload("res://assets/ui/play.svg")
const ICON_PAUSE := preload("res://assets/ui/pause.svg")
const ICON_RETRY := preload("res://assets/ui/retry.svg")
const ICON_HOME := preload("res://assets/ui/home.svg")
# Settings toggles: [icon when on, icon when off].
const TOGGLE_ICONS := {
	"sound": [preload("res://assets/ui/sound_on.svg"), preload("res://assets/ui/sound_off.svg")],
	"music": [preload("res://assets/ui/music_on.svg"), preload("res://assets/ui/music_off.svg")],
	"vibration": [preload("res://assets/ui/vibrate_on.svg"), preload("res://assets/ui/vibrate_off.svg")],
}
const GREY := [Color("8a9aa8"), Color("67757f")] # Toggle that's switched off.
const ICON_CARROT := preload("res://assets/kenney/carrots.png")
const POWERUP_ICONS := {
	"jetpack": preload("res://assets/kenney/powerup_jetpack.png"),
	"wings": preload("res://assets/kenney/powerup_wings.png"),
	"bubble": preload("res://assets/kenney/powerup_bubble.png"),
}

const ORANGE := [Color("f39c34"), Color("c2721b")] # [face, shadow]
const BLUE := [Color("3b9bd6"), Color("2a78a8")]
const INK := Color("1f3b57") # Dark blue for text and outlines.
const TOP_MARGIN := 60.0 # Keeps the score and pause button clear of the notch.
const BUTTONS_LOCK_TIME := 0.6 # Game-over buttons ignore taps briefly.
# Easter egg: tap the menu title this many times, each within the gap of the last.
const SECRET_TAPS := 7
const SECRET_TAP_GAP_MS := 1000

enum Screen { MENU, PLAYING, PAUSED, GAME_OVER }

var screen := Screen.MENU
var purple := false # Which skin the secret would switch *away* from.

var _score_label: Label
var _status: VBoxContainer # Carrot count and active power-ups, under the score.
var _carrot_label: Label
var _powerup_rows := {} # kind -> [row, ProgressBar or null]
var _menu_carrots: HBoxContainer
var _final_carrots: HBoxContainer
var _hint_label: Label
var _pause_button: Button
var _menu: Control
var _paused: Control
var _game_over: Control
var _menu_best: Label
var _final_score: Label
var _final_best: Label
var _game_over_buttons: Array[Button] = []
var _toggles := {} # name -> list of buttons (one per screen that shows it)
var _title: Label
var _toast: Label
var _toast_id := 0
var _title_taps := 0
var _last_tap_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_playing_ui()
	_build_menu()
	_build_paused()
	_build_game_over()


# --- Switching screens ------------------------------------------------------

func show_menu(best: int, total_carrots: int) -> void:
	screen = Screen.MENU
	_menu_best.text = "Best: %d" % best if best > 0 else ""
	_menu_carrots.visible = total_carrots > 0
	_menu_carrots.get_child(1).text = str(total_carrots)
	_show_only(_menu)


func show_playing() -> void:
	screen = Screen.PLAYING
	_show_only(null)


func show_paused() -> void:
	screen = Screen.PAUSED
	_show_only(_paused)


func show_game_over(score: int, best: int, new_best: bool, carrots: int) -> void:
	screen = Screen.GAME_OVER
	_final_score.text = str(score)
	_final_carrots.visible = carrots > 0
	_final_carrots.get_child(1).text = "+%d" % carrots
	_final_best.text = "New best!" if new_best else "Best: %d" % best
	_final_best.add_theme_color_override("font_color", ORANGE[1] if new_best else INK)
	_show_only(_game_over)
	for button in _game_over_buttons:
		button.disabled = true
	get_tree().create_timer(BUTTONS_LOCK_TIME).timeout.connect(func() -> void:
		for button in _game_over_buttons:
			button.disabled = false)


func set_score(score: int) -> void:
	_score_label.text = str(score)


func set_carrots(count: int) -> void:
	_carrot_label.text = str(count)


## Shows a row per active power-up; fractions are time left (0 = inactive).
func set_powerups(jetpack: float, wings: float, bubble: bool) -> void:
	for kind in _powerup_rows:
		var row: Control = _powerup_rows[kind][0]
		var bar: ProgressBar = _powerup_rows[kind][1]
		var left: float = {"jetpack": jetpack, "wings": wings, "bubble": 1.0 if bubble else 0.0}[kind]
		row.visible = left > 0.0
		if bar:
			bar.value = left


## Updates the sound / music / vibration buttons to show which are on.
func set_toggles(sound: bool, music: bool, vibration: bool) -> void:
	var on := {"sound": sound, "music": music, "vibration": vibration}
	for toggle_name in _toggles:
		for button: Button in _toggles[toggle_name]:
			button.icon = TOGGLE_ICONS[toggle_name][0 if on[toggle_name] else 1]
			_style_button(button, BLUE if on[toggle_name] else GREY)


## Shows a message in the middle of the screen for a few seconds.
func show_hint(text: String, seconds: float) -> void:
	_hint_label.text = text
	_hint_label.visible = true
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		_hint_label.visible = false)


## A short message near the bottom of the screen.
func show_toast(text: String, seconds: float = 1.5) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_id += 1
	var id := _toast_id
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if id == _toast_id: # Only hide if no newer toast replaced this one.
			_toast.visible = false)


func _on_title_input(event: InputEvent) -> void:
	# Touches arrive as emulated left clicks, so this covers phone and PC.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms > SECRET_TAP_GAP_MS:
		_title_taps = 0
	_last_tap_ms = now
	_title_taps += 1
	_bump(_title)

	var left := SECRET_TAPS - _title_taps
	if left == 0:
		_title_taps = 0
		secret_found.emit()
	elif left <= 3: # Like Android's "You are 3 steps away from being a developer."
		show_toast("%d tap%s away from %s..." % [left, "" if left == 1 else "s", "brown" if purple else "purple"])


func _bump(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.08, 1.08)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.15)


func _show_only(overlay: Control) -> void:
	_score_label.visible = screen == Screen.PLAYING or screen == Screen.PAUSED
	_status.visible = _score_label.visible
	_pause_button.visible = screen == Screen.PLAYING
	for o in [_menu, _paused, _game_over]:
		o.visible = o == overlay
	if screen != Screen.PLAYING:
		_hint_label.visible = false
	_toast.visible = false


# Keyboard shortcuts for testing on a PC: Esc pauses/resumes, Enter/Space plays.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if screen == Screen.PLAYING:
			pause_pressed.emit()
		elif screen == Screen.PAUSED:
			resume_pressed.emit()
	elif event.is_action_pressed("ui_accept"):
		if screen == Screen.MENU:
			play_pressed.emit()
		elif screen == Screen.PAUSED:
			resume_pressed.emit()
		elif screen == Screen.GAME_OVER and not _game_over_buttons[0].disabled:
			play_pressed.emit()


# --- Building the UI --------------------------------------------------------

func _build_playing_ui() -> void:
	_score_label = _label("0", 56, Color.WHITE, true)
	_score_label.position = Vector2(28, TOP_MARGIN)
	add_child(_score_label)

	_status = VBoxContainer.new()
	_status.position = Vector2(28, TOP_MARGIN + 74)
	_status.add_theme_constant_override("separation", 8)
	add_child(_status)
	var carrot_row := _icon_row(ICON_CARROT, "0", 40)
	_carrot_label = carrot_row.get_child(1)
	_status.add_child(carrot_row)
	for kind in POWERUP_ICONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_icon(POWERUP_ICONS[kind], 48))
		var bar: ProgressBar = null
		if kind != "bubble": # The bubble lasts until used, so no timer.
			bar = _timer_bar()
			row.add_child(bar)
		row.visible = false
		_status.add_child(row)
		_powerup_rows[kind] = [row, bar]

	_pause_button = _button("", ICON_PAUSE, BLUE, Vector2(96, 96))
	# Pinned to the top-right corner.
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -96 - 28
	_pause_button.offset_right = -28
	_pause_button.offset_top = TOP_MARGIN
	_pause_button.offset_bottom = TOP_MARGIN + 96
	_pause_button.pressed.connect(pause_pressed.emit)
	add_child(_pause_button)

	_hint_label = _label("", 44, Color.WHITE, true)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.visible = false
	add_child(_hint_label)

	# Sits over the dirt at the bottom, clear of the menu and the bunny.
	_toast = _label("", 36, Color.WHITE, true)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.9
	_toast.anchor_bottom = 0.96
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)


func _build_menu() -> void:
	_menu = _overlay(false)
	# Sit in the upper part of the screen so the bouncing bunny shows below.
	var box := _centered_column(_menu, 0.78)

	_title = _label("Bunny\nHop", 128, Color.WHITE, true)
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_constant_override("outline_size", 22)
	_title.add_theme_constant_override("line_spacing", -30)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP # Labels ignore taps by default.
	_title.gui_input.connect(_on_title_input)
	box.add_child(_title)

	_menu_best = _label("", 40, Color.WHITE, true)
	box.add_child(_menu_best)
	_menu_carrots = _icon_row(ICON_CARROT, "0", 40)
	_menu_carrots.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_menu_carrots)
	box.add_child(_spacer(20))

	var play := _button("Play", ICON_PLAY, ORANGE, Vector2(380, 120), 56)
	play.pressed.connect(play_pressed.emit)
	box.add_child(play)
	box.add_child(_toggle_row())

	var tip := _label("Tilt your phone to steer", 30, Color.WHITE, true)
	box.add_child(_spacer(10))
	box.add_child(tip)


func _build_paused() -> void:
	_paused = _overlay(true)
	var card := _card(_centered_column(_paused, 1.0))
	card.add_child(_label("Paused", 72, INK))
	card.add_child(_spacer(10))

	var resume := _button("Resume", ICON_PLAY, ORANGE, Vector2(380, 110))
	resume.pressed.connect(resume_pressed.emit)
	card.add_child(resume)
	card.add_child(_toggle_row())
	var menu := _button("Menu", ICON_HOME, BLUE, Vector2(380, 96))
	menu.pressed.connect(menu_pressed.emit)
	card.add_child(menu)


func _build_game_over() -> void:
	_game_over = _overlay(true)
	var card := _card(_centered_column(_game_over, 1.0))
	card.add_child(_label("Game Over", 64, INK))
	_final_score = _label("0", 110, ORANGE[0], true)
	_final_score.add_theme_color_override("font_outline_color", INK)
	card.add_child(_final_score)
	_final_best = _label("", 40, INK)
	card.add_child(_final_best)
	_final_carrots = _icon_row(ICON_CARROT, "+0", 40, false)
	_final_carrots.alignment = BoxContainer.ALIGNMENT_CENTER
	_final_carrots.get_child(1).add_theme_color_override("font_color", ORANGE[1])
	card.add_child(_final_carrots)
	card.add_child(_spacer(10))

	var again := _button("Play again", ICON_RETRY, ORANGE, Vector2(380, 110))
	again.pressed.connect(play_pressed.emit)
	card.add_child(again)
	var menu := _button("Menu", ICON_HOME, BLUE, Vector2(380, 96))
	menu.pressed.connect(menu_pressed.emit)
	card.add_child(menu)
	_game_over_buttons = [again, menu]


## Three square buttons: sound, music, vibration.
func _toggle_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	var signals := {"sound": sound_pressed, "music": music_pressed, "vibration": vibration_pressed}
	for toggle_name in TOGGLE_ICONS:
		var button := _button("", TOGGLE_ICONS[toggle_name][0], BLUE, Vector2(112, 100))
		button.add_theme_constant_override("icon_max_width", 56)
		button.pressed.connect(signals[toggle_name].emit)
		row.add_child(button)
		if not _toggles.has(toggle_name):
			_toggles[toggle_name] = []
		_toggles[toggle_name].append(button)
	return row


## Full-screen layer for a menu; `dim` darkens the game behind it.
func _overlay(dim: bool) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.45)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(shade)
	root.visible = false
	add_child(root)
	return root


## A vertical stack centered in the top `height_fraction` of the screen.
func _centered_column(parent: Control, height_fraction: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = height_fraction
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


## A rounded white panel holding its own vertical stack; returns the stack.
func _card(parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(44)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	return box


func _label(text: String, size: int, color: Color, outlined: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 12)
	return label


## An icon followed by a number, e.g. the carrot counter.
func _icon_row(icon: Texture2D, text: String, size: int, outlined: bool = true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_icon(icon, size))
	row.add_child(_label(text, size, Color.WHITE if outlined else INK, outlined))
	return row


func _icon(tex: Texture2D, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	return rect


func _timer_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(130, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.35)
	back.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE[0]
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


## A chunky rounded button with a darker "shadow" edge underneath that
## flattens when pressed, in the style of the Kenney art.
func _button(text: String, icon: Texture2D, colors: Array, min_size: Vector2, font_size: int = 44) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("icon_max_width", 52)
	button.add_theme_constant_override("h_separation", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	_style_button(button, colors)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _style_button(button: Button, colors: Array) -> void:
	button.add_theme_stylebox_override("normal", _button_style(colors, 10, 0))
	button.add_theme_stylebox_override("hover", _button_style(colors, 10, 0))
	button.add_theme_stylebox_override("pressed", _button_style(colors, 3, 7))
	button.add_theme_stylebox_override("disabled", _button_style([colors[0].darkened(0.2), colors[1].darkened(0.2)], 10, 0))


func _button_style(colors: Array, edge: int, push: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0]
	style.border_color = colors[1]
	style.border_width_bottom = edge
	style.set_corner_radius_all(28)
	style.content_margin_left = 28
	style.content_margin_right = 28
	# When pressed, the face drops down onto the shorter edge.
	style.expand_margin_top = -push
	style.content_margin_top = 8 + push
	style.content_margin_bottom = 8
	return style

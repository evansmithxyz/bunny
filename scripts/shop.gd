extends Control
## The carrot shop: buy and wear colors and hats, and buy upgrades. Changes the
## player's Profile directly and tells main.gd what happened through signals.
## Buying takes two taps (price, then "Buy?") so carrots aren't spent by accident.

signal closed
signal purchased(id: String)
signal equipped
signal denied # Tapped something that can't be bought right now.

const UI := preload("res://scripts/ui.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Profile := preload("res://scripts/profile.gd")
const Bunny := preload("res://scripts/bunny.gd")
const ICON_CARROT := preload("res://assets/kenney/carrots.png")
const ICON_HOME := preload("res://assets/ui/home.svg")

const TABS := ["Colors", "Hats", "Upgrades"]
const COLUMNS := 4
const CONFIRM_SECONDS := 2.5
const TOP_MARGIN := 60.0
const PREVIEW_SCALE := 0.9 # Bunny art pixels to screen pixels in the preview.
const HEAD_TOP_PX := 49.0 # Top of the head in the standing sprite.
const HAT_SINK_PX := 10.0 # Hats sit a little down onto the head.

var profile: Profile

var _tab := 0
var _balance: Label
var _preview_body: TextureRect
var _preview_hat: TextureRect
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _message: Label
var _message_id := 0
var _confirm_id := "" # Item waiting for its second "Buy?" tap.
var _confirm_ms := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", int(TOP_MARGIN))
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	# Top bar: back, title, carrot balance.
	var bar := HBoxContainer.new()
	var back := UI.button("", ICON_HOME, UI.BLUE, Vector2(96, 96))
	back.pressed.connect(closed.emit)
	bar.add_child(back)
	var title := UI.label("Shop", 64, Color.WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var balance_row := UI.icon_row(ICON_CARROT, "0", 44)
	balance_row.custom_minimum_size.x = 96 + 60 # Balances the back button so the title stays centered.
	balance_row.alignment = BoxContainer.ALIGNMENT_END
	_balance = balance_row.get_child(1)
	bar.add_child(balance_row)
	column.add_child(bar)

	column.add_child(_build_preview())

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	for i in TABS.size():
		var tab := UI.button(TABS[i], null, UI.BLUE, Vector2(0, 84), 36)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_on_tab_pressed.bind(i))
		tabs.add_child(tab)
		_tab_buttons.append(tab)
	column.add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_message = UI.label("", 34, Color.WHITE, true)
	_message.custom_minimum_size.y = 48
	column.add_child(_message)


## Shows the shop for this player's profile.
func open(player: Profile) -> void:
	profile = player
	_confirm_id = ""
	_message.text = ""
	refresh()


## Rebuilds everything to match the profile (balance, preview, item list).
func refresh() -> void:
	if profile == null:
		return
	_balance.text = str(profile.carrots)
	_update_preview()
	for i in _tab_buttons.size():
		UI.style_button(_tab_buttons[i], UI.ORANGE if i == _tab else UI.BLUE)
	for child in _scroll.get_children():
		_scroll.remove_child(child)
		child.queue_free()
	match _tab:
		0:
			_scroll.add_child(_item_grid(Catalog.COLORS, "color"))
		1:
			_scroll.add_child(_item_grid(Catalog.HATS, "hat"))
		2:
			_scroll.add_child(_upgrade_list())


func _on_tab_pressed(index: int) -> void:
	_tab = index
	_confirm_id = ""
	_scroll.scroll_vertical = 0
	equipped.emit() # Just for the click sound; nothing changes.
	refresh()


# --- Buying and wearing -----------------------------------------------------

func _on_item_pressed(id: String, kind: String) -> void:
	if kind != "upgrade" and profile.owns(id):
		_wear(id, kind)
		return

	var price := profile.price_of(id)
	if price < 0: # The secret purple bunny.
		_say("It's a secret... try tapping around the title screen")
		denied.emit()
		return
	if price > profile.carrots:
		_say("Need %d more carrots" % (price - profile.carrots))
		denied.emit()
		return

	var now := Time.get_ticks_msec()
	if _confirm_id != id or now - _confirm_ms > CONFIRM_SECONDS * 1000:
		_confirm_id = id # First tap: ask to confirm.
		_confirm_ms = now
		refresh()
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func() -> void:
			if _confirm_id == id and Time.get_ticks_msec() - _confirm_ms >= CONFIRM_SECONDS * 1000:
				_confirm_id = ""
				refresh())
		return

	_confirm_id = ""
	profile.buy(id)
	if kind != "upgrade":
		_wear(id, kind, false)
	_say("Bought!")
	purchased.emit(id)
	refresh()


func _wear(id: String, kind: String, announce: bool = true) -> void:
	if kind == "color":
		profile.color = id
	else:
		profile.hat = id
	if announce:
		equipped.emit()
	refresh()


func _say(text: String) -> void:
	_message.text = text
	_message_id += 1
	var id := _message_id
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if id == _message_id:
			_message.text = "")


# --- Building the lists -----------------------------------------------------

func _item_grid(items: Array, kind: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for item: Dictionary in items:
		var box := UI.card(grid, 10, 6)
		box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var secret: bool = item.get("secret", false) and not profile.owns(item.id)
		box.add_child(_thumbnail(item, kind, secret))
		var name_label := UI.label("???" if secret else item.name, 24, UI.INK)
		name_label.clip_text = true
		box.add_child(name_label)
		box.add_child(_item_button(item.id, kind))
	return grid


func _item_button(id: String, kind: String) -> Button:
	var owned := profile.owns(id)
	var worn := (profile.color if kind == "color" else profile.hat) == id
	var price := profile.price_of(id)
	var button: Button
	if worn:
		button = UI.button("On", null, UI.GREEN, Vector2(0, 60), 28)
	elif owned:
		button = UI.button("Wear", null, UI.BLUE, Vector2(0, 60), 28)
	elif price < 0:
		button = UI.button("Secret", null, UI.GREY, Vector2(0, 60), 26)
	elif _confirm_id == id:
		button = UI.button("Buy?", null, UI.ORANGE, Vector2(0, 60), 28)
	else:
		button = UI.button(str(price), ICON_CARROT, UI.ORANGE if price <= profile.carrots else UI.GREY, Vector2(0, 60), 28)
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 6)
	_tighten(button)
	button.pressed.connect(_on_item_pressed.bind(id, kind))
	return button


func _upgrade_list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	for item: Dictionary in Catalog.UPGRADES:
		var box := UI.card(list, 16, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		row.add_child(UI.icon(item.icon, 72))

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 2)
		var name_label := UI.label(item.name, 32, UI.INK)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(name_label)
		var desc := UI.label(item.desc, 22, Color("5d7185"))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(desc)
		var level := profile.level(item.id)
		var max_level: int = item.prices.size()
		if max_level > 1:
			text.add_child(_level_dots(level, max_level))
		row.add_child(text)

		var button: Button
		var price := profile.price_of(item.id)
		if price < 0:
			button = UI.button("Owned" if max_level == 1 else "Max", null, UI.GREEN, Vector2(150, 76), 30)
		elif _confirm_id == item.id:
			button = UI.button("Buy?", null, UI.ORANGE, Vector2(150, 76), 30)
		else:
			button = UI.button(str(price), ICON_CARROT, UI.ORANGE if price <= profile.carrots else UI.GREY, Vector2(150, 76), 30)
			button.add_theme_constant_override("icon_max_width", 34)
			button.add_theme_constant_override("h_separation", 6)
		_tighten(button)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_item_pressed.bind(item.id, "upgrade"))
		row.add_child(button)
	return list


## A row of dots, filled for each level owned.
func _level_dots(level: int, max_level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in max_level:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = UI.ORANGE[0] if i < level else Color(0, 0, 0, 0.12)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row


## Small buttons need less side padding than the big menu buttons.
func _tighten(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state)
		style.content_margin_left = 8
		style.content_margin_right = 8


# --- Bunny pictures ---------------------------------------------------------

func _thumbnail(item: Dictionary, kind: String, secret: bool) -> Control:
	if kind == "hat":
		var hat := UI.icon(item.get("texture"), 80) # "No hat" shows an empty space.
		return hat
	var body := UI.icon(_bunny_texture(item.id), 96)
	body.material = Catalog.color_material(item.id)
	if secret:
		# A dark silhouette until the easter egg is found.
		body.modulate = Color(0.1, 0.1, 0.15)
	return body


func _bunny_texture(color_id: String) -> Texture2D:
	return Bunny.PURPLE.stand if color_id == "purple" else Bunny.BROWN.stand


## The big bunny at the top, wearing the current color and hat.
func _build_preview() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.25)
	style.set_corner_radius_all(36)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 230)

	var center := CenterContainer.new()
	panel.add_child(center)
	var stage := Control.new() # Children placed by hand, not by a container.
	var body_size := Vector2(120, 201) * PREVIEW_SCALE
	stage.custom_minimum_size = Vector2(200, body_size.y + 20)
	center.add_child(stage)

	_preview_body = TextureRect.new()
	_preview_body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_body.size = body_size
	_preview_body.position = Vector2((200 - body_size.x) / 2.0, 20)
	stage.add_child(_preview_body)
	_preview_hat = TextureRect.new()
	_preview_hat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage.add_child(_preview_hat)
	return panel


func _update_preview() -> void:
	_preview_body.texture = _bunny_texture(profile.color)
	_preview_body.material = Catalog.color_material(profile.color)
	var hat_item := Catalog.find(Catalog.HATS, profile.hat)
	_preview_hat.visible = hat_item.has("texture")
	if _preview_hat.visible:
		var tex: Texture2D = hat_item.texture
		# Same proportions as in the game, where the hat is drawn at its "scale"
		# relative to the bunny art.
		var size: Vector2 = tex.get_size() * PREVIEW_SCALE * hat_item.scale
		var head := _preview_body.position + Vector2(_preview_body.size.x / 2.0, (HEAD_TOP_PX + HAT_SINK_PX) * PREVIEW_SCALE)
		_preview_hat.texture = tex
		_preview_hat.size = size
		_preview_hat.position = head - Vector2(size.x / 2.0, size.y)

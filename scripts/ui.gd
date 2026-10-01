extends RefCounted
## Shared look for the game's UI: colors and builders for chunky Kenney-style
## buttons, labels, icons and cards. Used by hud.gd and shop.gd.

const ORANGE := [Color("f39c34"), Color("c2721b")] # [face, shadow]
const BLUE := [Color("3b9bd6"), Color("2a78a8")]
const GREY := [Color("8a9aa8"), Color("67757f")] # Switched off / unavailable.
const GREEN := [Color("2ecc71"), Color("23a35a")]
const INK := Color("1f3b57") # Dark blue for text and outlines.


static func label(text: String, size: int, color: Color, outlined: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outlined:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 12)
	return l


static func icon(tex: Texture2D, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	return rect


## An icon followed by a number, e.g. the carrot counter.
static func icon_row(tex: Texture2D, text: String, size: int, outlined: bool = true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(icon(tex, size))
	row.add_child(label(text, size, Color.WHITE if outlined else INK, outlined))
	return row


static func spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


## A rounded white panel holding its own vertical stack; returns the stack.
static func card(parent: Control, padding: int = 44, separation: int = 22) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return box


static func timer_bar() -> ProgressBar:
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


## A chunky rounded button with a darker "shadow" edge underneath that
## flattens when pressed, in the style of the Kenney art.
static func button(text: String, tex: Texture2D, colors: Array, min_size: Vector2, font_size: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = tex
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("icon_max_width", 52)
	b.add_theme_constant_override("h_separation", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	style_button(b, colors)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Recolors a button made by button(), e.g. a toggle switching off.
static func style_button(b: Button, colors: Array) -> void:
	b.add_theme_stylebox_override("normal", _button_style(colors, 10, 0))
	b.add_theme_stylebox_override("hover", _button_style(colors, 10, 0))
	b.add_theme_stylebox_override("pressed", _button_style(colors, 3, 7))
	b.add_theme_stylebox_override("disabled", _button_style([colors[0].darkened(0.2), colors[1].darkened(0.2)], 10, 0))


static func _button_style(colors: Array, edge: int, push: int) -> StyleBoxFlat:
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

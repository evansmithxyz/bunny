extends Node2D
## A dashed line with a flag across the sky at the player's best height, so you
## can see your record coming. Place it at y = -best height. Fades away once
## passed (celebrate()).

const DASH := 26.0
const GAP := 16.0
const LINE_COLOR := Color(1, 1, 1, 0.85)
const SHADOW := Color(0, 0, 0, 0.18)
const FLAG_COLOR := Color("f39c34")
const POLE_COLOR := Color("5b3a29")

var screen_width := 720.0
var _passed := false


func _ready() -> void:
	var label := Label.new()
	label.text = "Best"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 10)
	label.position = Vector2(14, -44)
	add_child(label)


## The bunny just passed it: a quick flash, then it fades away.
func celebrate() -> void:
	if _passed:
		return
	_passed = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.6), 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)


func _draw() -> void:
	var x := 0.0
	while x < screen_width:
		var end := minf(x + DASH, screen_width)
		draw_line(Vector2(x, 3), Vector2(end, 3), SHADOW, 6.0)
		draw_line(Vector2(x, 0), Vector2(end, 0), LINE_COLOR, 5.0)
		x += DASH + GAP
	# A little flag on a pole near the right edge.
	var pole := Vector2(screen_width - 56, 0)
	draw_line(pole, pole + Vector2(0, -64), POLE_COLOR, 5.0)
	draw_colored_polygon(PackedVector2Array([
		pole + Vector2(2, -64), pole + Vector2(42, -52), pole + Vector2(2, -40),
	]), FLAG_COLOR)
	draw_circle(pole + Vector2(0, -66), 5.0, Color("f7d046"))

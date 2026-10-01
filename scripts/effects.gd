extends Node2D
## Visual effects in the game world: feather bursts, dust puffs, floating text.

const FEATHER := preload("res://assets/art/feather.svg")
const PUFF := preload("res://assets/kenney/smoke.png")

# Multiplied with each particle's color, so white keeps the color and just fades it.
var _fade_out := _make_fade_out()


func feathers(at: Vector2, color: Color) -> void:
	var p := _burst(at, 14, 0.7)
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 500)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.texture = FEATHER
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	p.color = color
	p.color_ramp = _fade_out


func dust(at: Vector2) -> void:
	var p := _burst(at, 10, 0.45)
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 200)
	p.texture = PUFF
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	p.color = Color(1.0, 0.95, 0.85)
	p.color_ramp = _fade_out


## Text that floats up and fades away, e.g. "Combo x3".
func popup(at: Vector2, text: String, color: Color = Color.WHITE, size: int = 36) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 5
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var box := label.get_combined_minimum_size()
	label.position = at - box / 2.0
	# Keep it on screen when the bunny is near a side (the camera spans x = 0..width).
	var width := get_viewport_rect().size.x
	label.position.x = clampf(label.position.x, 8.0, maxf(8.0, width - box.x - 8.0))

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 90.0, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _burst(at: Vector2, amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.z_index = 2
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true
	return p


static func _make_fade_out() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	return g

extends Node2D
## A floating carrot or power-up. Bobs gently; collected by touching the bunny.

const TEXTURES := {
	"carrot": preload("res://assets/kenney/carrot.png"),
	"gold_carrot": preload("res://assets/kenney/carrot_gold.png"),
	"jetpack": preload("res://assets/kenney/powerup_jetpack.png"),
	"wings": preload("res://assets/kenney/powerup_wings.png"),
	"bubble": preload("res://assets/kenney/powerup_bubble.png"),
}
const CARROT_SCALE := 0.55
const POWERUP_SCALE := 0.8
const CARROT_RADIUS := 26.0
const POWERUP_RADIUS := 34.0

var kind := "carrot"

var _time := randf() * TAU
var _home_y := 0.0
var _collected := false


func is_powerup() -> bool:
	return kind != "carrot" and kind != "gold_carrot"


func radius() -> float:
	return POWERUP_RADIUS if is_powerup() else CARROT_RADIUS


func _ready() -> void:
	_home_y = position.y


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _home_y + sin(_time * 3.0) * 6.0
	rotation = sin(_time * 2.0) * (0.0 if is_powerup() else 0.15)
	if is_powerup():
		queue_redraw() # Pulsing glow.


## Pops the pickup up and fades it out, then frees it.
func collect() -> void:
	_collected = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var tex: Texture2D = TEXTURES[kind]
	var s := POWERUP_SCALE if is_powerup() else CARROT_SCALE
	if is_powerup():
		var glow := 0.25 + 0.15 * sin(_time * 5.0)
		draw_circle(Vector2.ZERO, 42.0, Color(1, 1, 1, glow))
	var size := tex.get_size() * s
	draw_texture_rect(tex, Rect2(-size / 2.0, size), false)

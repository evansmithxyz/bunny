extends RefCounted
## Everything sold in the carrot shop. Change prices or add items here.
## Colors recolor the brown bunny with the bunny_color shader:
## [hue shift, saturation, brightness]. Purple is the title-screen easter egg.

const COLORS := [
	{"id": "brown", "name": "Brown", "price": 0, "hsv": [0.0, 1.0, 1.0]},
	{"id": "snow", "name": "Snow", "price": 100, "hsv": [0.0, 0.05, 1.65]},
	{"id": "pink", "name": "Pink", "price": 100, "hsv": [0.84, 0.75, 1.25]},
	{"id": "mint", "name": "Mint", "price": 150, "hsv": [0.34, 0.6, 1.25]},
	{"id": "sky", "name": "Sky", "price": 150, "hsv": [0.49, 0.7, 1.2]},
	{"id": "shadow", "name": "Shadow", "price": 200, "hsv": [0.0, 0.2, 0.55]},
	{"id": "golden", "name": "Golden", "price": 400, "hsv": [0.06, 1.15, 1.5]},
	{"id": "purple", "name": "Purple", "price": -1, "secret": true}, # Can't be bought; hidden until found.
]

# "scale" sizes the hat art relative to the bunny art: as big as possible while
# the ears still poke up around it (the narrow party hat can be bigger).
const HATS := [
	{"id": "none", "name": "No hat", "price": 0},
	{"id": "party", "name": "Party hat", "price": 75, "scale": 0.85, "texture": preload("res://assets/art/hat_party.svg")},
	{"id": "flower", "name": "Flower", "price": 120, "scale": 0.7, "texture": preload("res://assets/art/hat_flower.svg")},
	{"id": "top", "name": "Top hat", "price": 200, "scale": 0.7, "texture": preload("res://assets/art/hat_top.svg")},
	{"id": "crown", "name": "Crown", "price": 400, "scale": 0.7, "texture": preload("res://assets/art/hat_crown.svg")},
]

# "prices" has one entry per level.
const UPGRADES := [
	{"id": "jetpack", "name": "Longer jetpack", "desc": "+0.5s of flight per level",
		"prices": [60, 150, 300], "icon": preload("res://assets/kenney/powerup_jetpack.png")},
	{"id": "wings", "name": "Longer wings", "desc": "+1.5s of gliding per level",
		"prices": [60, 150, 300], "icon": preload("res://assets/kenney/powerup_wings.png")},
	{"id": "magnet", "name": "Carrot magnet", "desc": "Pulls in nearby carrots",
		"prices": [80, 200, 400], "icon": preload("res://assets/kenney/carrot.png")},
	{"id": "bubble_start", "name": "Bubble start", "desc": "Begin every run with a bubble",
		"prices": [250], "icon": preload("res://assets/kenney/powerup_bubble.png")},
]

# What each upgrade level does.
const JETPACK_BONUS_PER_LEVEL := 0.5 # Seconds.
const WINGS_BONUS_PER_LEVEL := 1.5 # Seconds.
const MAGNET_RADIUS := [0.0, 110.0, 170.0, 230.0] # By level.


static func find(list: Array, id: String) -> Dictionary:
	for item: Dictionary in list:
		if item.id == id:
			return item
	return list[0]


## A ShaderMaterial that recolors the bunny to the given color, or null for
## colors drawn without recoloring (brown and purple).
static func color_material(color_id: String) -> ShaderMaterial:
	var item := find(COLORS, color_id)
	if not item.has("hsv") or item.hsv == [0.0, 1.0, 1.0]:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/art/bunny_color.gdshader")
	mat.set_shader_parameter("hue_shift", item.hsv[0])
	mat.set_shader_parameter("saturation", item.hsv[1])
	mat.set_shader_parameter("brightness", item.hsv[2])
	return mat

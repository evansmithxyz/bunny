extends RefCounted
## The player's carrots and shop progress, stored in the save file:
## [scores] carrots, and [shop] owned / color / hat / trail / upgrade levels.

const Catalog := preload("res://scripts/catalog.gd")

var _cfg: ConfigFile
var _path: String


func _init(cfg: ConfigFile, path: String) -> void:
	_cfg = cfg
	_path = path
	# Older saves turned purple on with a setting; carry that over.
	if _cfg.get_value("settings", "purple", false) and not owns("purple"):
		unlock("purple")
		_cfg.set_value("shop", "color", "purple")
		_cfg.erase_section_key("settings", "purple")
		_save()


var carrots: int:
	get:
		return _cfg.get_value("scores", "carrots", 0)
	set(value):
		_cfg.set_value("scores", "carrots", value)
		_save()


var color: String:
	get:
		return _cfg.get_value("shop", "color", "brown")
	set(value):
		_cfg.set_value("shop", "color", value)
		_save()


var hat: String:
	get:
		return _cfg.get_value("shop", "hat", "none")
	set(value):
		_cfg.set_value("shop", "hat", value)
		_save()


var trail: String:
	get:
		return _cfg.get_value("shop", "trail", "none")
	set(value):
		_cfg.set_value("shop", "trail", value)
		_save()


func owns(id: String) -> bool:
	return id in ["brown", "none"] or id in _cfg.get_value("shop", "owned", [])


func unlock(id: String) -> void:
	if owns(id):
		return
	var owned: Array = _cfg.get_value("shop", "owned", [])
	owned.append(id)
	_cfg.set_value("shop", "owned", owned)
	_save()


func level(upgrade_id: String) -> int:
	return _cfg.get_value("shop", "level_" + upgrade_id, 0)


## Spends carrots on a color, hat or the next upgrade level. Returns false if
## it's already owned or maxed, or the player can't afford it.
func buy(id: String) -> bool:
	var price := price_of(id)
	if price < 0 or price > carrots:
		return false
	carrots -= price
	var upgrade := Catalog.find(Catalog.UPGRADES, id)
	if upgrade.id == id:
		_cfg.set_value("shop", "level_" + id, level(id) + 1)
		_save()
	else:
		unlock(id)
	return true


## Price of buying `id` now, or -1 if it can't be bought (owned, maxed, secret).
func price_of(id: String) -> int:
	for item: Dictionary in Catalog.COLORS + Catalog.HATS + Catalog.TRAILS:
		if item.id == id:
			return -1 if owns(id) or item.price < 0 else item.price
	var upgrade := Catalog.find(Catalog.UPGRADES, id)
	if upgrade.id == id and level(id) < upgrade.prices.size():
		return upgrade.prices[level(id)]
	return -1


func _save() -> void:
	_cfg.save(_path)

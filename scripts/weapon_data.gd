extends RefCounted
## Central weapon stat table for Cat Commando.
##
## The future TikTok LIVE bridge will call CatPlayer.set_weapon() /
## activate_*() with these ids, so keep them stable:
## "default", "machinegun", "minigun", "rocket".
## Tune all numbers here; no other script hardcodes weapon stats.

const ORDER: Array[String] = ["default", "machinegun", "minigun", "rocket"]

const STATS := {
	"default": {
		"name": "Default Gun",
		"interval": 0.35,
		"projectile_speed": 750.0,
		"damage": 1,
		"bullet_radius": 6.0,
		"pellets": 1,
		"spread": 0.0,
		"gun_length": 36.0,
		"gun_width": 10.0,
		"gun_color": Color(0.5, 0.55, 0.6),
		"muzzle_flash": false,
	},
	"machinegun": {
		"name": "Machine Gun",
		"interval": 0.15,
		"projectile_speed": 850.0,
		"damage": 1,
		"bullet_radius": 4.0,
		"pellets": 1,
		"spread": 0.03,
		"gun_length": 42.0,
		"gun_width": 8.0,
		"gun_color": Color(0.3, 0.7, 1.0),
		"muzzle_flash": false,
	},
	"minigun": {
		"name": "Giant Minigun",
		"interval": 0.10,
		"projectile_speed": 900.0,
		"damage": 1,
		"bullet_radius": 5.0,
		"pellets": 3,
		"spread": 0.09,
		"gun_length": 52.0,
		"gun_width": 18.0,
		"gun_color": Color(1.0, 0.55, 0.15),
		"muzzle_flash": true,
	},
	"rocket": {
		"name": "Rocket Launcher",
		"interval": 0.9,
		"projectile_speed": 460.0,
		"damage": 3,
		"aoe_damage": 3,
		"aoe_radius": 120.0,
		"pellets": 1,
		"spread": 0.0,
		"gun_length": 48.0,
		"gun_width": 20.0,
		"gun_color": Color(0.8, 0.2, 0.2),
		"muzzle_flash": true,
	},
}

static func is_valid(weapon_id: String) -> bool:
	return STATS.has(weapon_id)

static func get_stat(weapon_id: String) -> Dictionary:
	if STATS.has(weapon_id):
		return STATS[weapon_id]
	return STATS["default"]

static func display_name(weapon_id: String) -> String:
	return String(get_stat(weapon_id).get("name", weapon_id))

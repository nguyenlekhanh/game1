class_name CatPlayer
extends CharacterBody2D

## Cat Commando player: automatic targeting + modular weapon system.
##
## Future TikTok LIVE bridge API (all callable remotely later):
##   set_weapon("machinegun" | "minigun" | "rocket" | "default")
##   restore_default_weapon()
##   activate_rapid_fire(duration)
##   activate_giant_gun(duration)
##   fire_mega_laser()

signal health_changed(current: int, maximum: int)
signal died
signal fired
signal weapon_changed(weapon_id: String)

const ARENA_MIN := Vector2(60, 90)
const ARENA_MAX := Vector2(1220, 660)

const MAX_PROJECTILES := 150
const MAX_ROCKETS := 12
const RAPID_MULTIPLIER := 0.35
const MIN_INTERVAL := 0.06
const LASER_COOLDOWN := 8.0
const LASER_DAMAGE := 6
const GIANT_GUN_DURATION := 8.0
const RAPID_DURATION := 5.0

@export var max_health: int = 100
@export var move_speed: float = 280.0

@export_group("Sprites")
@export var use_sprites_when_available: bool = true
@export_file("*.png", "*.jpg") var cat_texture_path: String = "res://assets/characters/cat_idle.png"
@export_file("*.png", "*.jpg") var default_gun_texture_path: String = "res://assets/weapons/gun_default.png"
@export_file("*.png", "*.jpg") var minigun_texture_path: String = "res://assets/weapons/gun_minigun.png"
@export var cat_sprite_scale: Vector2 = Vector2(0.25, 0.25)
@export var weapon_offset: Vector2 = Vector2(10, 8)
@export var default_gun_scale: Vector2 = Vector2(0.4, 0.4)
@export var minigun_scale: Vector2 = Vector2(0.5, 0.5)

var health: int = 100
var alive: bool = true
var aim_angle: float = 0.0
var has_target: bool = false
var current_weapon: String = "default"

var _cat_texture: Texture2D = null
var _default_gun_texture: Texture2D = null
var _minigun_texture: Texture2D = null

var _fire_timer: float = 0.0
var _rapid_timer: float = 0.0
var _temp_weapon_timer: float = 0.0
var _prev_weapon: String = "default"
var _laser_cd: float = 0.0
var _bullet_container: Node2D = null
var _fx_container: Node2D = null

const BulletScript := preload("res://scripts/bullet.gd")
const RocketScript := preload("res://scripts/rocket.gd")
const LaserScript := preload("res://scripts/mega_laser.gd")
const Weapons := preload("res://scripts/weapon_data.gd")

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	health = max_health
	_bullet_container = get_tree().get_first_node_in_group("bullet_container") as Node2D
	_fx_container = get_tree().get_first_node_in_group("effect_container") as Node2D
	_load_sprites()
	if not weapon_changed.is_connected(_on_weapon_changed):
		weapon_changed.connect(_on_weapon_changed)
	_update_weapon_sprite()

func _body_sprite_active() -> bool:
	return use_sprites_when_available and alive and _cat_texture != null and $BodySprite != null

func _weapon_sprite_active() -> bool:
	return use_sprites_when_available and alive and _current_gun_texture() != null and $WeaponMount/WeaponSprite != null

func _current_gun_texture() -> Texture2D:
	if current_weapon == "minigun":
		return _minigun_texture
	if current_weapon == "default":
		return _default_gun_texture
	# Machine gun / rocket launcher have no PNG yet: placeholder art.
	return null

func _try_load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		if path != "":
			push_warning("CatPlayer: sprite missing, using placeholder: %s" % path)
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is Texture2D:
		return res as Texture2D
	push_warning("CatPlayer: not a Texture2D, using placeholder: %s" % path)
	return null

func _load_sprites() -> void:
	_cat_texture = _try_load_texture(cat_texture_path)
	_default_gun_texture = _try_load_texture(default_gun_texture_path)
	_minigun_texture = _try_load_texture(minigun_texture_path)
	var body := $BodySprite as Sprite2D
	if body != null:
		body.texture = _cat_texture
		body.scale = cat_sprite_scale
		body.visible = _body_sprite_active()
	var mount := $WeaponMount as Node2D
	if mount != null:
		mount.position = weapon_offset

func _on_weapon_changed(_weapon_id: String) -> void:
	_update_weapon_sprite()

func _update_weapon_sprite() -> void:
	var sprite := $WeaponMount/WeaponSprite as Sprite2D
	if sprite == null:
		return
	var tex := _current_gun_texture()
	sprite.texture = tex
	if current_weapon == "minigun":
		sprite.scale = minigun_scale
	else:
		sprite.scale = default_gun_scale
	sprite.visible = _weapon_sprite_active()
	queue_redraw()

func _update_sprite_pose() -> void:
	var mount := $WeaponMount as Node2D
	if mount != null:
		mount.rotation = aim_angle
	var facing_left := cos(aim_angle) < 0.0
	var gun_sprite := $WeaponMount/WeaponSprite as Sprite2D
	if gun_sprite != null:
		# Keep the gun upright when aiming left instead of upside-down.
		gun_sprite.flip_v = facing_left
	var body := $BodySprite as Sprite2D
	if body != null:
		body.flip_h = facing_left

# ---------------------------------------------------------------- abilities --

func is_rapid_fire() -> bool:
	return _rapid_timer > 0.0

func is_giant_gun_active() -> bool:
	return _temp_weapon_timer > 0.0

func activate_rapid_fire(duration: float = RAPID_DURATION) -> void:
	_rapid_timer = maxf(_rapid_timer, duration)

func set_weapon(weapon_id: String) -> bool:
	if not Weapons.is_valid(weapon_id):
		return false
	# A permanent switch cancels any temporary weapon override.
	_temp_weapon_timer = 0.0
	_prev_weapon = weapon_id
	if current_weapon != weapon_id:
		current_weapon = weapon_id
		_fire_timer = minf(_fire_timer, 0.05)
		weapon_changed.emit(current_weapon)
		queue_redraw()
	return true

func restore_default_weapon() -> void:
	set_weapon("default")

func activate_giant_gun(duration: float = GIANT_GUN_DURATION) -> void:
	if not alive:
		return
	if _temp_weapon_timer <= 0.0:
		_prev_weapon = current_weapon
		current_weapon = "minigun"
		weapon_changed.emit(current_weapon)
	_temp_weapon_timer = maxf(_temp_weapon_timer, duration)
	_fire_timer = minf(_fire_timer, 0.05)
	queue_redraw()

func is_laser_ready() -> bool:
	return alive and _laser_cd <= 0.0

func fire_mega_laser() -> bool:
	if not is_laser_ready():
		return false
	if _fx_container == null:
		_fx_container = get_tree().get_first_node_in_group("effect_container") as Node2D
	if _fx_container == null:
		return false
	_laser_cd = LASER_COOLDOWN
	var dir := Vector2.RIGHT.rotated(aim_angle)
	_fx_container.add_child(LaserScript.create(global_position + dir * 30.0, dir, LASER_DAMAGE))
	fired.emit()
	return true

func get_weapon_name() -> String:
	return Weapons.display_name(current_weapon)

func get_giant_gun_time_left() -> float:
	return maxf(0.0, _temp_weapon_timer)

func get_rapid_time_left() -> float:
	return maxf(0.0, _rapid_timer)

func get_laser_cooldown_left() -> float:
	return maxf(0.0, _laser_cd)

func get_ability_text() -> String:
	var text := ""
	if is_rapid_fire():
		text += "RAPID %.1fs" % _rapid_timer
	if is_giant_gun_active():
		if text != "":
			text += "  •  "
		text += "GIANT GUN %.1fs" % _temp_weapon_timer
	if text != "":
		text += "  •  "
	if _laser_cd > 0.0:
		text += "LASER %.1fs" % _laser_cd
	else:
		text += "LASER READY"
	return text

# ------------------------------------------------------------------ update --

func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Movement (optional; the cat fights automatically but can reposition).
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	move_and_slide()
	# Clamp inside arena so the fixed camera always frames the cat.
	position.x = clampf(position.x, ARENA_MIN.x, ARENA_MAX.x)
	position.y = clampf(position.y, ARENA_MIN.y, ARENA_MAX.y)

	# Tick ability timers with delta time.
	if _rapid_timer > 0.0:
		_rapid_timer -= delta
	if _laser_cd > 0.0:
		_laser_cd -= delta
	if _temp_weapon_timer > 0.0:
		_temp_weapon_timer -= delta
		if _temp_weapon_timer <= 0.0:
			# Giant Gun expired: restore the previous weapon.
			_temp_weapon_timer = 0.0
			current_weapon = _prev_weapon if Weapons.is_valid(_prev_weapon) else "default"
			weapon_changed.emit(current_weapon)
			queue_redraw()

	_update_aim()
	_update_sprite_pose()
	_fire_timer -= delta
	if has_target and _fire_timer <= 0.0:
		_shoot()
	queue_redraw()

func _update_aim() -> void:
	var target := _find_nearest_enemy()
	if target != null:
		has_target = true
		aim_angle = (target.global_position - global_position).angle()
	else:
		has_target = false

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist := INF
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e.get("alive") == false:
			continue
		var d := global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = e as Node2D
	return best

func _projectile_count() -> int:
	return get_tree().get_nodes_in_group("projectiles").size()

func _rocket_count() -> int:
	return get_tree().get_nodes_in_group("rockets").size()

func _shoot() -> void:
	var stats: Dictionary = Weapons.get_stat(current_weapon)
	var interval := float(stats.get("interval", 0.35))
	if is_rapid_fire():
		interval = maxf(MIN_INTERVAL, interval * RAPID_MULTIPLIER)
	_fire_timer = interval
	if _projectile_count() >= MAX_PROJECTILES:
		return
	if _bullet_container == null:
		_bullet_container = get_tree().get_first_node_in_group("bullet_container") as Node2D
	if _bullet_container == null:
		return
	if current_weapon == "rocket":
		_shoot_rocket(stats)
	else:
		_shoot_bullets(stats)
	_spawn_muzzle_flash(stats)
	fired.emit()

func _shoot_bullets(stats: Dictionary) -> void:
	var pellets := int(stats.get("pellets", 1))
	var spread := float(stats.get("spread", 0.0))
	var speed := float(stats.get("projectile_speed", 750.0))
	var dmg := int(stats.get("damage", 1))
	var radius := float(stats.get("bullet_radius", 6.0))
	var gun_len := float(stats.get("gun_length", 36.0))
	for i in range(pellets):
		var ang := aim_angle
		if pellets > 1:
			# Even fan around the aim direction.
			ang += lerpf(-spread, spread, float(i) / float(pellets - 1))
		elif spread > 0.0:
			ang += randf_range(-spread, spread)
		var dir := Vector2.RIGHT.rotated(ang)
		var muzzle := global_position + dir * (gun_len - 2.0)
		_bullet_container.add_child(BulletScript.create(muzzle, dir, dmg, speed, radius))

func _shoot_rocket(stats: Dictionary) -> void:
	if _rocket_count() >= MAX_ROCKETS:
		return
	var speed := float(stats.get("projectile_speed", 460.0))
	var dmg := int(stats.get("damage", 3))
	var gun_len := float(stats.get("gun_length", 48.0))
	var dir := Vector2.RIGHT.rotated(aim_angle)
	var muzzle := global_position + dir * (gun_len - 2.0)
	_bullet_container.add_child(RocketScript.create(muzzle, dir, dmg, speed, float(stats.get("aoe_radius", 120.0))))

func _spawn_muzzle_flash(stats: Dictionary) -> void:
	if not bool(stats.get("muzzle_flash", false)):
		return
	if _fx_container == null:
		_fx_container = get_tree().get_first_node_in_group("effect_container") as Node2D
	if _fx_container == null:
		return
	if not Explosion.can_spawn_fx(get_tree()):
		return
	var dir := Vector2.RIGHT.rotated(aim_angle)
	var muzzle := global_position + dir * float(stats.get("gun_length", 40.0))
	_fx_container.add_child(Explosion.create(muzzle, Color(1.0, 0.85, 0.3), 18.0))

# ------------------------------------------------------------------ damage --

func take_damage(amount: int) -> void:
	if not alive:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		alive = false
		_hide_sprites()
		died.emit()

func heal(amount: int) -> void:
	if not alive:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func _hide_sprites() -> void:
	var body := $BodySprite as Sprite2D
	if body != null:
		body.visible = false
	var gun_sprite := $WeaponMount/WeaponSprite as Sprite2D
	if gun_sprite != null:
		gun_sprite.visible = false
	queue_redraw()

# ------------------------------------------------------------------ visuals --

func _draw() -> void:
	if not alive:
		# Wreck: grey outline only.
		draw_circle(Vector2.ZERO, 22.0, Color(0.25, 0.25, 0.3, 0.6))
		return
	# Shadow.
	_draw_shadow_ellipse(Vector2(0, 20), 24.0, 8.0, Color(0, 0, 0, 0.35))
	# Weapon: PNG on the mount when available, placeholder art otherwise.
	# (Firing math is unchanged; only the visuals switch.)
	if not _weapon_sprite_active():
		_draw_gun(Vector2.RIGHT.rotated(aim_angle), Weapons.get_stat(current_weapon))
	if is_rapid_fire():
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 24, Color(0.3, 1.0, 1.0, 0.8), 2.0, true)
	if is_giant_gun_active():
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 24, Color(1.0, 0.6, 0.15, 0.9), 3.0, true)
	# Body: cat_idle.png when available, placeholder cat otherwise.
	if not _body_sprite_active():
		_draw_placeholder_body(Vector2.RIGHT.rotated(aim_angle))
	# Aim indicator when a target exists.
	if has_target:
		var gun_dir := Vector2.RIGHT.rotated(aim_angle)
		var aim_tip := gun_dir * 52.0
		draw_circle(aim_tip, 3.0, Color(1.0, 0.3, 0.2, 0.9))
		draw_arc(aim_tip, 7.0, 0.0, TAU, 16, Color(1.0, 0.3, 0.2, 0.6), 1.5, true)

func _draw_placeholder_body(gun_dir: Vector2) -> void:
	# Original orange commando cat: kept as fallback when cat_idle.png
	# is missing, so the game never breaks without assets.
	draw_circle(Vector2.ZERO, 22.0, Color(0.95, 0.55, 0.12))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.55, 0.28, 0.05), 3.0, true)
	# Ears.
	var ear_l := PackedVector2Array([Vector2(-16, -12), Vector2(-20, -30), Vector2(-4, -18)])
	var ear_r := PackedVector2Array([Vector2(16, -12), Vector2(20, -30), Vector2(4, -18)])
	draw_colored_polygon(ear_l, Color(0.95, 0.55, 0.12))
	draw_colored_polygon(ear_r, Color(0.95, 0.55, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -15), Vector2(-18, -25), Vector2(-8, -18)]), Color(1.0, 0.75, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(16, -15), Vector2(18, -25), Vector2(8, -18)]), Color(1.0, 0.75, 0.55))
	# Headband (commando).
	draw_line(Vector2(-20, -8), Vector2(20, -8), Color(0.15, 0.4, 0.15), 6.0, true)
	draw_line(Vector2(14, -8), Vector2(26, -2), Color(0.15, 0.4, 0.15), 3.0, true)
	# Eyes look toward aim.
	var look := gun_dir * 4.0
	draw_circle(Vector2(-8, 0) + look, 6.5, Color.WHITE)
	draw_circle(Vector2(8, 0) + look, 6.5, Color.WHITE)
	draw_circle(Vector2(-8, 0) + look + gun_dir * 2.0, 3.0, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(8, 0) + look + gun_dir * 2.0, 3.0, Color(0.1, 0.1, 0.12))
	# Nose + stripes.
	draw_circle(Vector2(0, 9) + gun_dir * 1.5, 2.5, Color(0.9, 0.3, 0.3))
	draw_line(Vector2(-4, -22), Vector2(-4, -16), Color(0.55, 0.28, 0.05), 2.0, true)
	draw_line(Vector2(4, -22), Vector2(4, -16), Color(0.55, 0.28, 0.05), 2.0, true)

func _draw_gun(gun_dir: Vector2, stats: Dictionary) -> void:
	var gun_len := float(stats.get("gun_length", 36.0))
	var gun_w := float(stats.get("gun_width", 10.0))
	var gun_col := stats.get("gun_color", Color(0.5, 0.55, 0.6)) as Color
	var gun_base := gun_dir * 10.0
	var gun_tip := gun_dir * gun_len
	if current_weapon == "minigun":
		# Triple rotating-style barrels: clearly bigger than the default gun.
		var perp := gun_dir.rotated(PI * 0.5)
		for offset in [-6.0, 0.0, 6.0]:
			draw_line(gun_base + perp * offset, gun_tip + perp * offset, Color(0.15, 0.15, 0.18), 7.0, true)
			draw_line(gun_base + perp * offset, gun_tip + perp * offset, gun_col, 4.0, true)
		# Ammo drum.
		draw_circle(gun_dir * 14.0, 9.0, Color(0.2, 0.2, 0.22))
		draw_arc(gun_dir * 14.0, 9.0, 0.0, TAU, 16, gun_col, 2.5, true)
	elif current_weapon == "rocket":
		# Thick launch tube with warning stripes.
		draw_line(gun_base, gun_tip, Color(0.12, 0.12, 0.14), gun_w + 4.0, true)
		draw_line(gun_base, gun_tip, Color(0.35, 0.35, 0.38), gun_w, true)
		draw_line(gun_base + gun_dir * 8.0, gun_base + gun_dir * 16.0, Color(1.0, 0.8, 0.1), gun_w, true)
		draw_circle(gun_tip, gun_w * 0.45, Color(0.1, 0.1, 0.1))
	else:
		draw_line(gun_base, gun_tip, Color(0.15, 0.15, 0.18), gun_w, true)
		draw_line(gun_base, gun_tip, gun_col, gun_w - 4.0, true)
		draw_circle(gun_tip, 4.0, Color(1.0, 0.8, 0.2))

# Helper: filled ellipse shadow drawn as a polygon (avoids depending on
# the engine's CanvasItem.draw_ellipse signature across 4.x versions).
func _draw_shadow_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

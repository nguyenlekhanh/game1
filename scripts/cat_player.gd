class_name CatPlayer
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died
signal fired

const ARENA_MIN := Vector2(60, 90)
const ARENA_MAX := Vector2(1220, 660)

@export var max_health: int = 100
@export var move_speed: float = 280.0
@export var fire_interval: float = 0.35
@export var bullet_speed: float = 750.0
@export var bullet_damage: int = 1

var health: int = 100
var alive: bool = true
var aim_angle: float = 0.0
var has_target: bool = false

var _fire_timer: float = 0.0
var _rapid_timer: float = 0.0
var _bullet_container: Node2D = null

const BulletScript := preload("res://scripts/bullet.gd")

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	health = max_health
	_bullet_container = get_tree().get_first_node_in_group("bullet_container") as Node2D

func is_rapid_fire() -> bool:
	return _rapid_timer > 0.0

func activate_rapid_fire(duration: float = 5.0) -> void:
	_rapid_timer = duration

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

	if _rapid_timer > 0.0:
		_rapid_timer -= delta

	_update_aim()
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

func _shoot() -> void:
	var interval := fire_interval
	if is_rapid_fire():
		interval = 0.09
	_fire_timer = interval
	if _bullet_container == null:
		_bullet_container = get_tree().get_first_node_in_group("bullet_container") as Node2D
	if _bullet_container == null:
		return
	var dir := Vector2.RIGHT.rotated(aim_angle)
	var muzzle := global_position + dir * 34.0
	var b := BulletScript.create(muzzle, dir, bullet_damage, bullet_speed)
	_bullet_container.add_child(b)
	# Nudge bullet to top-level coords (container sits at origin, so this is exact).
	fired.emit()

func take_damage(amount: int) -> void:
	if not alive:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		alive = false
		died.emit()

func heal(amount: int) -> void:
	if not alive:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func _draw() -> void:
	if not alive:
		# Wreck: grey outline only.
		draw_circle(Vector2.ZERO, 22.0, Color(0.25, 0.25, 0.3, 0.6))
		return
	# Shadow.
	_draw_shadow_ellipse(Vector2(0, 20), 24.0, 8.0, Color(0, 0, 0, 0.35))
	# Weapon (rotated toward aim) drawn under body so it looks held.
	var gun_dir := Vector2.RIGHT.rotated(aim_angle)
	var gun_perp := gun_dir.rotated(PI * 0.5)
	var gun_base := gun_dir * 10.0
	var gun_tip := gun_dir * 36.0
	draw_line(gun_base, gun_tip, Color(0.15, 0.15, 0.18), 10.0, true)
	draw_line(gun_base, gun_tip, Color(0.5, 0.55, 0.6), 6.0, true)
	draw_circle(gun_tip, 4.0, Color(1.0, 0.8, 0.2))
	if is_rapid_fire():
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 24, Color(0.3, 1.0, 1.0, 0.8), 2.0, true)
	# Body: orange commando cat.
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
	# Aim indicator when a target exists.
	if has_target:
		var aim_tip := gun_dir * 52.0
		draw_circle(aim_tip, 3.0, Color(1.0, 0.3, 0.2, 0.9))
		draw_arc(aim_tip, 7.0, 0.0, TAU, 16, Color(1.0, 0.3, 0.2, 0.6), 1.5, true)

# Helper: filled ellipse shadow drawn as a polygon (avoids depending on
# the engine's CanvasItem.draw_ellipse signature across 4.x versions).
func _draw_shadow_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

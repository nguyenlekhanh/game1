class_name Rocket
extends Area2D

## Slow homing rocket: direct hit + area damage explosion.
## Joins "bullets" (cleared on game over), "projectiles" (global cap)
## and "rockets" (per-type cap) groups.

signal exploded

@export var speed: float = 460.0
@export var damage: int = 3
@export var aoe_damage: int = 3
@export var aoe_radius: float = 120.0
@export var life_time: float = 3.0
@export var turn_rate: float = 3.2
@export var homing_range: float = 520.0

var velocity: Vector2 = Vector2.RIGHT
var age: float = 0.0
var _dead: bool = false

const ExplosionScript := preload("res://scripts/explosion.gd")

static func create(start_pos: Vector2, direction: Vector2, rocket_damage: int = 3, rocket_speed: float = 460.0, blast_radius: float = 120.0) -> Rocket:
	var r := Rocket.new()
	r.position = start_pos
	r.velocity = direction.normalized()
	r.damage = rocket_damage
	r.aoe_damage = rocket_damage
	r.speed = rocket_speed
	r.aoe_radius = blast_radius
	r.collision_layer = 4
	r.collision_mask = 2
	r.monitoring = true
	r.monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	r.add_child(shape)
	r.body_entered.connect(r._on_body_entered)
	r.area_entered.connect(r._on_area_entered)
	return r

func _ready() -> void:
	add_to_group("bullets")
	add_to_group("projectiles")
	add_to_group("rockets")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	age += delta
	if age >= life_time:
		_explode()
		return
	_apply_homing(delta)
	position += velocity * speed * delta
	if position.x < -80.0 or position.x > 1360.0 or position.y < -80.0 or position.y > 800.0:
		queue_free()
		return
	queue_redraw()

func _apply_homing(delta: float) -> void:
	var target := _find_homing_target()
	if target == null:
		return
	var desired := (target.global_position - global_position).normalized()
	var current_ang := velocity.angle()
	var desired_ang := desired.angle()
	var diff := wrapf(desired_ang - current_ang, -PI, PI)
	var max_turn := turn_rate * delta
	velocity = velocity.rotated(clampf(diff, -max_turn, max_turn)).normalized()

func _find_homing_target() -> Node2D:
	var best: Node2D = null
	var best_dist := homing_range * homing_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.get("alive") == false:
			continue
		var d := global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = e as Node2D
	return best

func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage, velocity)
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	if area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage, velocity)
		_explode()

func _explode() -> void:
	if _dead:
		return
	_dead = true
	# Area damage around impact point.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.get("alive") == false:
			continue
		var node := e as Node2D
		if node.global_position.distance_to(global_position) <= aoe_radius + 8.0:
			if e.has_method("take_damage"):
				e.take_damage(aoe_damage, (node.global_position - global_position).normalized())
	# Capped impact effect so rocket spam can't flood the renderer.
	var fx_container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if fx_container != null and ExplosionScript.can_spawn_fx(get_tree()):
		fx_container.add_child(ExplosionScript.create(global_position, Color(1.0, 0.45, 0.1), aoe_radius))
	exploded.emit()
	queue_free()

func _draw() -> void:
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector2.RIGHT
	var perp := dir.rotated(PI * 0.5)
	# Exhaust flame (flickers with age).
	var flick := 10.0 + sin(age * 40.0) * 4.0
	var flame := PackedVector2Array([-dir * 8.0 + perp * 4.0, -dir * (8.0 + flick), -dir * 8.0 - perp * 4.0])
	draw_colored_polygon(flame, Color(1.0, 0.6, 0.1, 0.9))
	# Warhead body.
	draw_line(-dir * 8.0, dir * 10.0, Color(0.85, 0.15, 0.15), 12.0, true)
	draw_line(-dir * 8.0, dir * 10.0, Color(0.95, 0.9, 0.9), 5.0, true)
	draw_circle(dir * 10.0, 5.0, Color(1.0, 0.85, 0.2))
	# Fins.
	draw_colored_polygon(PackedVector2Array([-dir * 2.0, -dir * 8.0 + perp * 9.0, -dir * 8.0 + perp * 3.0]), Color(0.5, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([-dir * 2.0, -dir * 8.0 - perp * 9.0, -dir * 8.0 - perp * 3.0]), Color(0.5, 0.1, 0.1))

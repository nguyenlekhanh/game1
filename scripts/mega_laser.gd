class_name MegaLaser
extends Node2D

## Arena-wide laser: short charge-up, then a bright beam that damages
## every enemy intersecting the beam segment once. Self-frees.
## Joins "bullets" so game-over cleanup removes a live beam.

@export var damage: int = 6
@export var beam_length: float = 1500.0
@export var half_width: float = 26.0
@export var charge_time: float = 0.6
@export var fire_time: float = 0.5

var direction: Vector2 = Vector2.RIGHT
var age: float = 0.0
var _did_damage: bool = false

static func create(origin: Vector2, beam_dir: Vector2, beam_damage: int = 6) -> MegaLaser:
	var l := MegaLaser.new()
	l.position = origin
	l.direction = beam_dir.normalized() if beam_dir.length() > 0.01 else Vector2.RIGHT
	l.damage = beam_damage
	return l

func total_time() -> float:
	return charge_time + fire_time

func is_firing() -> bool:
	return age >= charge_time

func _ready() -> void:
	add_to_group("bullets")

func _process(delta: float) -> void:
	age += delta
	if not _did_damage and age >= charge_time:
		_did_damage = true
		_apply_damage()
	if age >= total_time():
		queue_free()
		return
	queue_redraw()

func _apply_damage() -> void:
	var end := direction * beam_length
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.get("alive") == false:
			continue
		var node := e as Node2D
		# Enemy position in laser-local space (laser sits at origin point).
		var local: Vector2 = node.global_position - global_position
		var touch := half_width + float(e.get("body_radius") if e.get("body_radius") != null else 14.0)
		if _point_segment_distance(local, Vector2.ZERO, end) <= touch:
			if e.has_method("take_damage"):
				e.take_damage(damage, direction)

func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _draw() -> void:
	var end := direction * beam_length
	if not is_firing():
		# Charging: thin flickering preview + growing charge glow.
		var t := clampf(age / charge_time, 0.0, 1.0)
		var flick := 0.4 + 0.6 * absf(sin(age * 30.0))
		draw_line(Vector2.ZERO, end, Color(0.4, 1.0, 1.0, 0.25 * flick), 4.0, true)
		draw_circle(Vector2.ZERO, 10.0 + 26.0 * t, Color(0.5, 1.0, 1.0, 0.35 + 0.4 * t))
		draw_circle(Vector2.ZERO, 8.0, Color(1.0, 1.0, 1.0, 0.8))
	else:
		# Firing: layered beam — wide glow, mid cyan, white-hot core.
		var fade := 1.0
		var left := total_time() - age
		if left < 0.2:
			fade = clampf(left / 0.2, 0.0, 1.0)
		draw_line(Vector2.ZERO, end, Color(0.3, 0.9, 1.0, 0.30 * fade), half_width * 2.6, true)
		draw_line(Vector2.ZERO, end, Color(0.4, 1.0, 1.0, 0.75 * fade), half_width * 1.4, true)
		draw_line(Vector2.ZERO, end, Color(1.0, 1.0, 1.0, 0.95 * fade), half_width * 0.55, true)
		draw_circle(Vector2.ZERO, half_width * 1.2, Color(1.0, 1.0, 1.0, 0.9 * fade))

class_name Explosion
extends Node2D

var max_radius: float = 42.0
var duration: float = 0.35
var age: float = 0.0
var base_color: Color = Color(1.0, 0.6, 0.15)

const MAX_FX := 30

static func create(pos: Vector2, color: Color = Color(1.0, 0.6, 0.15), radius: float = 42.0, duration: float = 0.35) -> Explosion:
	var e := Explosion.new()
	e.position = pos
	e.base_color = color
	e.max_radius = radius
	e.duration = duration
	return e

static func fx_count(tree: SceneTree) -> int:
	if tree == null:
		return 0
	return tree.get_nodes_in_group("effects").size()

static func can_spawn_fx(tree: SceneTree) -> bool:
	return fx_count(tree) < MAX_FX

func _ready() -> void:
	add_to_group("effects")

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	var r := max_radius * ease(t, 0.4)
	var alpha := 1.0 - t
	# Outer shockwave ring.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(base_color, alpha * 0.9), 4.0, true)
	# Inner flash.
	draw_circle(Vector2.ZERO, r * 0.6 * (1.0 - t * 0.5), Color(1.0, 1.0, 1.0, alpha * 0.8))
	draw_circle(Vector2.ZERO, r * 0.35 * (1.0 - t * 0.4), Color(base_color, alpha))

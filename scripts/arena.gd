class_name Arena
extends Node2D

const ARENA_MIN := Vector2(40, 70)
const ARENA_MAX := Vector2(1240, 680)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Deep-space background.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.04, 0.05, 0.09))
	# Subtle vignette bands.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 120)), Color(0.07, 0.09, 0.16, 0.6))
	# Neon grid.
	var grid_col := Color(0.15, 0.35, 0.55, 0.35)
	for x in range(0, 1281, 64):
		draw_line(Vector2(x, 0), Vector2(x, 720), grid_col, 1.0)
	for y in range(0, 721, 64):
		draw_line(Vector2(0, y), Vector2(1280, y), grid_col, 1.0)
	# Arena floor.
	draw_rect(Rect2(ARENA_MIN, ARENA_MAX - ARENA_MIN), Color(0.08, 0.11, 0.18, 0.95))
	# Decorative circuit dots.
	for i in range(12):
		var px := 120.0 + float(i) * 92.0
		draw_circle(Vector2(px, 640.0), 3.0, Color(0.2, 0.8, 1.0, 0.4))
		draw_circle(Vector2(px, 110.0), 2.0, Color(0.2, 0.8, 1.0, 0.25))
	# Glowing arena border (double line for neon look).
	draw_rect(Rect2(ARENA_MIN, ARENA_MAX - ARENA_MIN), Color(0.1, 0.8, 1.0, 0.25), false, 8.0)
	draw_rect(Rect2(ARENA_MIN, ARENA_MAX - ARENA_MIN), Color(0.3, 0.95, 1.0), false, 2.0)
	# Corner accents.
	var c := Color(1.0, 0.6, 0.1)
	var l := 26.0
	for corner in [ARENA_MIN, Vector2(ARENA_MAX.x, ARENA_MIN.y), Vector2(ARENA_MIN.x, ARENA_MAX.y), ARENA_MAX]:
		var sx := 1.0 if corner.x < 640.0 else -1.0
		var sy := 1.0 if corner.y < 360.0 else -1.0
		draw_line(corner, corner + Vector2(sx * l, 0), c, 4.0, true)
		draw_line(corner, corner + Vector2(0, sy * l), c, 4.0, true)

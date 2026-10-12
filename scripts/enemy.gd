class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, score_value: int)

const CONTACT_DISTANCE := 40.0

var enemy_type: String = "chaser"
var max_hp: int = 2
var hp: int = 2
var speed: float = 110.0
var damage: int = 10
var score_value: int = 1
var alive: bool = true
var body_radius: float = 16.0

var _contact_timer: float = 0.0
var _flash_timer: float = 0.0
var _wobble: float = 0.0

const ExplosionScript := preload("res://scripts/explosion.gd")

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	_wobble = randf() * TAU

func setup(p_type: String = "chaser") -> void:
	enemy_type = p_type
	match enemy_type:
		"speeder":
			max_hp = 1
			hp = 1
			speed = 210.0
			damage = 6
			score_value = 1
			body_radius = 12.0
		"tank":
			max_hp = 6
			hp = 6
			speed = 60.0
			damage = 20
			score_value = 3
			body_radius = 24.0
		"boss":
			max_hp = 60
			hp = 60
			speed = 50.0
			damage = 25
			score_value = 20
			body_radius = 38.0
			add_to_group("boss")
		_:
			enemy_type = "chaser"
			max_hp = 2
			hp = 2
			speed = 110.0
			damage = 10
			score_value = 1
			body_radius = 16.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_wobble += delta * 6.0
	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()
	_contact_timer -= delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		if player.get("alive") == true:
			var to_player: Vector2 = (player.global_position - global_position)
			var dist := to_player.length()
			if dist > 1.0:
				velocity = to_player.normalized() * speed
			else:
				velocity = Vector2.ZERO
			move_and_slide()
			# Contact damage with per-enemy cooldown so health drains fairly.
			if dist < CONTACT_DISTANCE + body_radius * 0.4 and _contact_timer <= 0.0:
				_contact_timer = 0.8
				if player.has_method("take_damage"):
					player.take_damage(damage)
	queue_redraw()

func take_damage(amount: int, _from_dir: Vector2 = Vector2.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	_flash_timer = 0.09
	if hp <= 0:
		_die()
	else:
		queue_redraw()

func _die() -> void:
	if not alive:
		return
	alive = false
	_spawn_explosion()
	died.emit(self, score_value)
	queue_free()

func _spawn_explosion() -> void:
	var fx_container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if fx_container == null:
		return
	var col := Color(1.0, 0.4, 0.2)
	match enemy_type:
		"speeder":
			col = Color(1.0, 0.3, 0.8)
		"tank":
			col = Color(0.7, 0.4, 1.0)
		"boss":
			col = Color(1.0, 0.2, 0.1)
	var fx := ExplosionScript.create(global_position, col, body_radius + 26.0)
	fx_container.add_child(fx)

func _draw() -> void:
	var flash := _flash_timer > 0.0
	var bob := sin(_wobble) * 1.5
	var c := Vector2(0, bob)
	match enemy_type:
		"speeder":
			_draw_speeder(c, flash)
		"tank":
			_draw_tank(c, flash)
		"boss":
			_draw_boss(c, flash)
		_:
			_draw_chaser(c, flash)
	# HP pips above tanks / damaged enemies.
	if max_hp > 2 or hp < max_hp:
		var w := 30.0
		var frac := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
		var y := -body_radius - 12.0
		draw_line(c + Vector2(-w * 0.5, y), c + Vector2(w * 0.5, y), Color(0, 0, 0, 0.7), 5.0, true)
		draw_line(c + Vector2(-w * 0.5, y), c + Vector2(-w * 0.5 + w * frac, y), Color(0.3, 1.0, 0.4), 5.0, true)

func _draw_chaser(c: Vector2, flash: bool) -> void:
	var body := Color(1.0, 0.25, 0.2) if not flash else Color.WHITE
	var dark := Color(0.55, 0.08, 0.08) if not flash else Color.WHITE
	var r := body_radius
	var tri := PackedVector2Array([c + Vector2(0, -r - 4), c + Vector2(r, r), c + Vector2(-r, r)])
	draw_colored_polygon(tri, body)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), dark, 3.0, true)
	# Angry eye.
	draw_circle(c + Vector2(0, 4), 6.0, Color.WHITE if not flash else Color(1, 1, 1))
	draw_circle(c + Vector2(0, 5), 3.0, Color(0.6, 0.05, 0.05))
	draw_line(c + Vector2(-9, -4), c + Vector2(9, -4), Color(0.2, 0.02, 0.02), 3.0, true)

func _draw_speeder(c: Vector2, flash: bool) -> void:
	var body := Color(1.0, 0.25, 0.75) if not flash else Color.WHITE
	var dark := Color(0.5, 0.05, 0.35) if not flash else Color.WHITE
	var r := body_radius
	var diamond := PackedVector2Array([c + Vector2(0, -r - 3), c + Vector2(r, 0), c + Vector2(0, r + 3), c + Vector2(-r, 0)])
	draw_colored_polygon(diamond, body)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), dark, 2.5, true)
	# Speed fins.
	draw_line(c + Vector2(-r - 6, -4), c + Vector2(-r + 2, 0), Color(1, 1, 1, 0.7), 2.0, true)
	draw_line(c + Vector2(-r - 6, 4), c + Vector2(-r + 2, 4), Color(1, 1, 1, 0.7), 2.0, true)
	draw_circle(c, 4.5, Color(0.15, 0.02, 0.1))

func _draw_tank(c: Vector2, flash: bool) -> void:
	var body := Color(0.55, 0.3, 0.95) if not flash else Color.WHITE
	var dark := Color(0.28, 0.12, 0.5) if not flash else Color.WHITE
	var r := body_radius
	var pts := PackedVector2Array()
	for i in range(6):
		var a := TAU * float(i) / 6.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, body)
	var closed := pts + PackedVector2Array([pts[0]])
	draw_polyline(closed, dark, 4.0, true)
	# Armor core.
	draw_circle(c, 9.0, dark)
	draw_circle(c, 5.5, Color(1.0, 0.85, 0.2) if not flash else Color.WHITE)

func _draw_boss(c: Vector2, flash: bool) -> void:
	var body := Color(0.65, 0.08, 0.10) if not flash else Color.WHITE
	var dark := Color(0.30, 0.03, 0.05) if not flash else Color.WHITE
	var gold := Color(1.0, 0.8, 0.2) if not flash else Color.WHITE
	var r := body_radius
	# Spiked outer ring.
	var spikes := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0 + _wobble * 0.15
		spikes.append(c + Vector2(cos(a), sin(a)) * (r + 8.0))
		spikes.append(c + Vector2(cos(a + PI / 10.0), sin(a + PI / 10.0)) * (r - 2.0))
	draw_colored_polygon(spikes, dark)
	# Massive hull.
	draw_circle(c, r, body)
	draw_arc(c, r, 0.0, TAU, 40, dark, 5.0, true)
	draw_arc(c, r * 0.7, 0.0, TAU, 32, Color(1.0, 0.3, 0.2, 0.8), 3.0, true)
	# Crown.
	var crown := PackedVector2Array([
		c + Vector2(-20, -r + 6), c + Vector2(-20, -r - 12),
		c + Vector2(-10, -r + 0), c + Vector2(0, -r - 14),
		c + Vector2(10, -r + 0), c + Vector2(20, -r - 12),
		c + Vector2(20, -r + 6),
	])
	draw_colored_polygon(crown, gold)
	# Burning eyes.
	var pulse := 0.7 + 0.3 * sin(_wobble * 2.0)
	draw_circle(c + Vector2(-12, -4), 8.0, Color(1.0, 0.2 * pulse, 0.1))
	draw_circle(c + Vector2(12, -4), 8.0, Color(1.0, 0.2 * pulse, 0.1))
	draw_circle(c + Vector2(-12, -4), 3.5, Color.WHITE)
	draw_circle(c + Vector2(12, -4), 3.5, Color.WHITE)
	# Jagged maw.
	draw_line(c + Vector2(-14, 16), c + Vector2(14, 16), Color(0.1, 0.0, 0.0), 4.0, true)
	for i in range(4):
		var fx := -10.5 + float(i) * 7.0
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(fx, 16), c + Vector2(fx + 3.5, 22), c + Vector2(fx + 7.0, 16),
		]), Color.WHITE)

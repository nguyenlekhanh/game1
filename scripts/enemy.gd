class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, score_value: int)
signal enraged(enemy: Enemy)

const CONTACT_DISTANCE := 40.0

# Iron Behemoth tuning. Single table so LIVE-gift scaling can reuse it later.
const BOSS_CONFIG := {
	"max_hp": 150,
	"speed": 55.0,
	"contact_damage": 25,
	"score": 50,
	"body_radius": 40.0,
	"attack_interval": 5.0,
	"attack_interval_enraged": 2.8,
	"speed_mult_enraged": 1.4,
	"telegraph_time": 0.8,
	"burst_count": 5,
	"burst_fan": 0.38,
	"burst_damage": 8,
	"burst_speed": 330.0,
	"slam_windup": 0.7,
	"slam_radius": 260.0,
	"slam_damage": 15,
	"slam_cooldown": 7.0,
}

const BOSS_ARENA_MIN := Vector2(60, 90)
const BOSS_ARENA_MAX := Vector2(1220, 660)

# Boss state machine: chase <-> telegraphed attacks.
const BSTATE_CHASE := 0
const BSTATE_TELEGRAPH_BURST := 1
const BSTATE_TELEGRAPH_SLAM := 2

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
# Boss-only state (ignored for normal enemies).
var is_enraged: bool = false
var _bstate: int = 0
var _attack_timer: float = 3.0
var _state_timer: float = 0.0
var _state_total: float = 1.0
var _slam_cd: float = 0.0

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
			max_hp = int(BOSS_CONFIG["max_hp"])
			hp = max_hp
			speed = float(BOSS_CONFIG["speed"])
			damage = int(BOSS_CONFIG["contact_damage"])
			score_value = int(BOSS_CONFIG["score"])
			body_radius = float(BOSS_CONFIG["body_radius"])
			is_enraged = false
			_bstate = BSTATE_CHASE
			_attack_timer = 2.5
			_slam_cd = 0.0
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
	if enemy_type == "boss":
		_boss_physics(delta)
		return
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
		return
	# Enrage triggers once when crossing 30% HP.
	if enemy_type == "boss" and not is_enraged and hp <= int(float(max_hp) * 0.3):
		is_enraged = true
		enraged.emit(self)
	queue_redraw()

func _player_node() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and player.get("alive") == true:
		return player
	return null

func _boss_physics(delta: float) -> void:
	_contact_timer -= delta
	_slam_cd -= delta
	var player := _player_node()
	var smult := float(BOSS_CONFIG["speed_mult_enraged"])
	var move_speed := speed * (smult if is_enraged else 1.0)
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		var dist := to_player.length()
		if _bstate == BSTATE_CHASE:
			# Chase the cat; clamped inside the arena like the player.
			if dist > 1.0:
				velocity = to_player.normalized() * move_speed
			else:
				velocity = Vector2.ZERO
			move_and_slide()
			position.x = clampf(position.x, BOSS_ARENA_MIN.x, BOSS_ARENA_MAX.x)
			position.y = clampf(position.y, BOSS_ARENA_MIN.y, BOSS_ARENA_MAX.y)
			# Contact damage, same convention as normal enemies.
			if dist < CONTACT_DISTANCE + body_radius * 0.4 and _contact_timer <= 0.0:
				_contact_timer = 0.8
				if player.has_method("take_damage"):
					player.take_damage(damage)
			# Attack cycle (paused while the cat is dead: player == null).
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_begin_boss_attack(dist)
		else:
			# Telegraphing: hold still so the attack is readable.
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_execute_boss_attack(player)
	queue_redraw()

func _boss_attack_interval() -> float:
	if is_enraged:
		return float(BOSS_CONFIG["attack_interval_enraged"])
	return float(BOSS_CONFIG["attack_interval"])

func _begin_boss_attack(dist_to_player: float) -> void:
	var slam_radius := float(BOSS_CONFIG["slam_radius"])
	if dist_to_player <= slam_radius * 1.15 and _slam_cd <= 0.0:
		_bstate = BSTATE_TELEGRAPH_SLAM
		_state_total = float(BOSS_CONFIG["slam_windup"])
	else:
		_bstate = BSTATE_TELEGRAPH_BURST
		_state_total = float(BOSS_CONFIG["telegraph_time"])
	_state_timer = _state_total
	queue_redraw()

func _execute_boss_attack(player: Node2D) -> void:
	if _bstate == BSTATE_TELEGRAPH_BURST:
		_fire_burst(player)
	elif _bstate == BSTATE_TELEGRAPH_SLAM:
		_do_slam(player)
	_bstate = BSTATE_CHASE
	_attack_timer = _boss_attack_interval()
	queue_redraw()

func _fire_burst(player: Node2D) -> void:
	var container := get_tree().get_first_node_in_group("bullet_container") as Node2D
	if container == null or player == null or not is_instance_valid(player):
		return
	var count := int(BOSS_CONFIG["burst_count"])
	var fan := float(BOSS_CONFIG["burst_fan"])
	var dmg := int(BOSS_CONFIG["burst_damage"])
	var spd := float(BOSS_CONFIG["burst_speed"])
	var base_ang := (player.global_position - global_position).angle()
	for i in range(count):
		var ang := base_ang
		if count > 1:
			ang += lerpf(-fan, fan, float(i) / float(count - 1))
		var dir := Vector2.RIGHT.rotated(ang)
		container.add_child(EnemyBullet.create(global_position + dir * (body_radius + 6.0), dir, dmg, spd))

func _do_slam(player: Node2D) -> void:
	_slam_cd = float(BOSS_CONFIG["slam_cooldown"])
	var slam_radius := float(BOSS_CONFIG["slam_radius"])
	var fx_container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if fx_container != null and ExplosionScript.can_spawn_fx(get_tree()):
		fx_container.add_child(Explosion.create(global_position, Color(1.0, 0.45, 0.1), slam_radius, 0.5))
	# Single damage application, only inside the shockwave range.
	if player != null and is_instance_valid(player):
		if player.global_position.distance_to(global_position) <= slam_radius:
			if player.has_method("take_damage"):
				player.take_damage(int(BOSS_CONFIG["slam_damage"]))

func _die() -> void:
	if not alive:
		return
	alive = false
	if enemy_type == "boss":
		_die_boss_cleanup()
	_spawn_explosion()
	died.emit(self, score_value)
	queue_free()

func _die_boss_cleanup() -> void:
	# Stop everything boss-owned: attacks halt (alive == false) and its
	# projectiles are removed so they can't damage the player after death.
	_bstate = BSTATE_CHASE
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		if is_instance_valid(s):
			s.queue_free()

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
	if enemy_type == "boss":
		# Big, slightly longer death blast for the Behemoth.
		fx = ExplosionScript.create(global_position, Color(1.0, 0.5, 0.1), body_radius + 90.0, 0.8)
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
	# IRON BEHEMOTH: dark metallic armor + glowing orange energy core.
	# Pure drawing code, ~2.5-3x the visual size of a chaser.
	var armor := Color(0.16, 0.17, 0.22) if not flash else Color.WHITE
	var plate := Color(0.28, 0.30, 0.38) if not flash else Color.WHITE
	var edge := Color(0.55, 0.60, 0.70) if not flash else Color.WHITE
	var core_col := Color(1.0, 0.45, 0.08) if not is_enraged else Color(1.0, 0.12, 0.05)
	if flash:
		core_col = Color.WHITE
	var r := body_radius
	var pulse := 0.7 + 0.3 * sin(_wobble * 2.0)
	# Enrage aura.
	if is_enraged and not flash:
		draw_arc(c, r + 14.0 + sin(_wobble * 3.0) * 3.0, 0.0, TAU, 40, Color(1.0, 0.2, 0.05, 0.7), 4.0, true)
	# Telegraph visuals (readable wind-ups).
	if alive and _bstate == BSTATE_TELEGRAPH_BURST and not flash:
		var prog := 1.0 - clampf(_state_timer / maxf(0.01, _state_total), 0.0, 1.0)
		for k in range(3):
			var rr := lerpf(r + 46.0, r + 10.0, prog) + float(k) * 10.0
			draw_arc(c, rr, -0.6 + float(k) * 0.15, 0.6 + float(k) * 0.15, 16, Color(1.0, 0.6, 0.1, 0.8), 3.0, true)
	elif alive and _bstate == BSTATE_TELEGRAPH_SLAM and not flash:
		var sfrac := 1.0 - clampf(_state_timer / maxf(0.01, _state_total), 0.0, 1.0)
		var warn_r := lerpf(30.0, float(BOSS_CONFIG["slam_radius"]), sfrac)
		draw_arc(Vector2(0, 6), warn_r, 0.0, TAU, 48, Color(1.0, 0.15, 0.05, 0.35 + 0.45 * sfrac), 4.0, true)
	# Shoulder pauldrons (wide silhouette).
	draw_circle(c + Vector2(-r * 0.95, -r * 0.25), r * 0.55, armor)
	draw_circle(c + Vector2(r * 0.95, -r * 0.25), r * 0.55, armor)
	draw_arc(c + Vector2(-r * 0.95, -r * 0.25), r * 0.55, 0.0, TAU, 24, edge, 3.0, true)
	draw_arc(c + Vector2(r * 0.95, -r * 0.25), r * 0.55, 0.0, TAU, 24, edge, 3.0, true)
	# Horn spikes.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * r * 0.55, -r * 0.75),
			c + Vector2(side * (r * 0.95), -r * 1.45),
			c + Vector2(side * r * 1.05, -r * 0.65),
		]), plate)
	# Armored hull.
	var hull := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		hull.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(hull, armor)
	var closed := hull + PackedVector2Array([hull[0]])
	draw_polyline(closed, edge, 4.0, true)
	# Armor plate seams.
	draw_line(c + Vector2(-r * 0.7, -r * 0.2), c + Vector2(-r * 0.25, r * 0.55), edge, 2.0, true)
	draw_line(c + Vector2(r * 0.7, -r * 0.2), c + Vector2(r * 0.25, r * 0.55), edge, 2.0, true)
	# Glowing energy core.
	draw_circle(c, 16.0 * pulse + 6.0, Color(core_col, 0.30))
	draw_circle(c, 13.0, core_col)
	draw_circle(c, 6.5, Color(1.0, 0.95, 0.8))
	# Menacing eyes above the core.
	draw_circle(c + Vector2(-20, -r * 0.45), 5.5, Color(1.0, 0.3 + 0.4 * pulse, 0.1))
	draw_circle(c + Vector2(20, -r * 0.45), 5.5, Color(1.0, 0.3 + 0.4 * pulse, 0.1))

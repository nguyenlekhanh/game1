class_name SpawnManager
extends Node2D

signal enemy_count_changed(count: int)

const ARENA_MIN := Vector2(60, 90)
const ARENA_MAX := Vector2(1220, 660)

@export var enemy_scene: PackedScene
@export var start_interval: float = 1.5
@export var min_interval: float = 0.35
@export var interval_step: float = 0.12
@export var ramp_every_seconds: float = 10.0
@export var max_enemies: int = 40
@export var auto_spawn: bool = true
@export var boss_cooldown: float = 20.0

var current_interval: float = 1.5
var _spawn_timer: float = 0.0
var _ramp_timer: float = 0.0
var _boss_cd: float = 0.0
var running: bool = true

func _ready() -> void:
	add_to_group("spawn_manager")
	current_interval = start_interval
	_spawn_timer = 0.5

func _process(delta: float) -> void:
	if not running:
		return
	if _boss_cd > 0.0:
		_boss_cd -= delta
	# Difficulty ramp: spawn faster over time, clamped at min_interval.
	_ramp_timer += delta
	if _ramp_timer >= ramp_every_seconds:
		_ramp_timer = 0.0
		current_interval = maxf(min_interval, current_interval - interval_step)
	if not auto_spawn:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = current_interval
		if get_enemy_count() < max_enemies:
			spawn_enemy()

func get_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func get_boss() -> Enemy:
	for b in get_tree().get_nodes_in_group("boss"):
		if b != null and is_instance_valid(b) and b.get("alive") == true:
			return b as Enemy
	return null

func has_boss() -> bool:
	return get_boss() != null

func get_boss_cooldown_left() -> float:
	return maxf(0.0, _boss_cd)

func spawn_boss() -> Enemy:
	# Guard: only one boss at a time; repeated inputs return the live boss.
	var existing := get_boss()
	if existing != null:
		return existing
	# Cooldown after the previous boss died: no boss spam.
	if _boss_cd > 0.0:
		return null
	if enemy_scene == null:
		push_warning("SpawnManager: enemy_scene is not assigned.")
		return null
	if get_enemy_count() >= max_enemies + 10:
		return null
	var boss := enemy_scene.instantiate() as Enemy
	boss.setup("boss")
	boss.position = _random_edge_position()
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null:
		if gm.has_method("_on_enemy_died"):
			if not boss.died.is_connected(Callable(gm, "_on_enemy_died")):
				boss.died.connect(Callable(gm, "_on_enemy_died"))
		if gm.has_method("_on_boss_enraged"):
			if not boss.enraged.is_connected(Callable(gm, "_on_boss_enraged")):
				boss.enraged.connect(Callable(gm, "_on_boss_enraged"))
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = self
	parent_node.add_child.call_deferred(boss)
	enemy_count_changed.emit(get_enemy_count())
	return boss

func notify_boss_defeated() -> void:
	# Starts the cooldown window before another boss may be summoned.
	_boss_cd = boss_cooldown

func spawn_enemy(force_type: String = "") -> Enemy:
	if enemy_scene == null:
		push_warning("SpawnManager: enemy_scene is not assigned.")
		return null
	if get_enemy_count() >= max_enemies + 10:
		return null  # Absolute safety cap even for debug spawns.
	var enemy := enemy_scene.instantiate() as Enemy
	var t := force_type
	if t == "":
		t = _pick_random_type()
	enemy.setup(t)
	enemy.position = _random_edge_position()
	# Wire score signal through the game manager.
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("_on_enemy_died"):
		if not enemy.died.is_connected(Callable(gm, "_on_enemy_died")):
			enemy.died.connect(Callable(gm, "_on_enemy_died"))
	# Enemies are siblings of the player under Main so coordinates match.
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = self
	parent_node.add_child.call_deferred(enemy)
	enemy_count_changed.emit(get_enemy_count())
	return enemy

func _pick_random_type() -> String:
	var roll := randf()
	var elapsed := 0.0
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.get("elapsed") != null:
		elapsed = float(gm.get("elapsed"))
	# Tanks appear after ~25s, speeders after ~10s.
	if elapsed > 25.0:
		if roll < 0.55:
			return "chaser"
		elif roll < 0.8:
			return "speeder"
		else:
			return "tank"
	elif elapsed > 10.0:
		if roll < 0.65:
			return "chaser"
		else:
			return "speeder"
	return "chaser"

func _random_edge_position() -> Vector2:
	var side := randi() % 4
	match side:
		0:
			return Vector2(randf_range(ARENA_MIN.x, ARENA_MAX.x), ARENA_MIN.y + 10.0)
		1:
			return Vector2(randf_range(ARENA_MIN.x, ARENA_MAX.x), ARENA_MAX.y - 10.0)
		2:
			return Vector2(ARENA_MIN.x + 10.0, randf_range(ARENA_MIN.y, ARENA_MAX.y))
		_:
			return Vector2(ARENA_MAX.x - 10.0, randf_range(ARENA_MIN.y, ARENA_MAX.y))
	return Vector2(ARENA_MIN.x + 10.0, ARENA_MIN.y + 10.0)

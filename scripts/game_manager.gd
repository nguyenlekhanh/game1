class_name GameManager
extends Node2D

signal score_changed(score: int)
signal game_over(score: int, time_survived: float)

var score: int = 0
var elapsed: float = 0.0
var running: bool = true
var kills: int = 0

@onready var player: CatPlayer = $CatPlayer
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var hud: HUDManager = $HUD

func _ready() -> void:
	add_to_group("game_manager")
	randomize()
	if player != null:
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health, player.max_health)
	score_changed.emit(score)
	if hud != null:
		hud.set_score(score)
		hud.set_game_over_visible(false)

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if hud != null:
		hud.set_time(elapsed)
		hud.set_enemy_count(get_enemy_count())
		hud.set_spawn_interval(spawn_manager.current_interval if spawn_manager != null else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		# Debug: E spawns an enemy, F triggers rapid-fire power-up.
		if k == KEY_E:
			if spawn_manager != null and running:
				spawn_manager.spawn_enemy()
				get_viewport().set_input_as_handled()
		elif k == KEY_F:
			if player != null and running:
				player.activate_rapid_fire(5.0)
				if hud != null:
					hud.show_powerup_message("RAPID FIRE! (5s)")
				get_viewport().set_input_as_handled()
		elif k == KEY_R:
			# Quick keyboard restart once the game is over (button also works).
			if not running:
				restart_game()
				get_viewport().set_input_as_handled()

func _on_enemy_died(_enemy: Enemy, score_value: int) -> void:
	if not running:
		return
	score += score_value
	kills += 1
	score_changed.emit(score)
	if hud != null:
		hud.set_score(score)

func _on_player_health_changed(current: int, maximum: int) -> void:
	if hud != null:
		hud.set_health(current, maximum)

func _on_player_died() -> void:
	if not running:
		return
	running = false
	if spawn_manager != null:
		spawn_manager.running = false
	# Clear remaining bullets so the death screen is calm.
	for b in get_tree().get_nodes_in_group("bullets"):
		if is_instance_valid(b):
			b.queue_free()
	game_over.emit(score, elapsed)
	if hud != null:
		hud.show_game_over(score, elapsed)

func get_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func get_spawn_interval() -> float:
	if spawn_manager != null:
		return spawn_manager.current_interval
	return 0.0

func restart_game() -> void:
	# reload_current_scene resets score, timers, enemies and effects cleanly.
	get_tree().paused = false
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_error("GameManager: failed to reload scene (error %d)." % err)

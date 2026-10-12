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
		hud.set_boss_visible(false)
		if player != null:
			hud.set_weapon(player.get_weapon_name())
			hud.set_abilities(player.get_ability_text())

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if hud != null:
		hud.set_time(elapsed)
		hud.set_enemy_count(get_enemy_count())
		hud.set_spawn_interval(spawn_manager.current_interval if spawn_manager != null else 0.0)
		if player != null:
			hud.set_weapon(player.get_weapon_name())
			hud.set_abilities(player.get_ability_text())
		hud.set_debug_status(_debug_status_text())
		_refresh_boss_bar()

func _refresh_boss_bar() -> void:
	if hud == null or spawn_manager == null:
		return
	var boss := spawn_manager.get_boss()
	if boss == null:
		hud.set_boss_visible(false)
	else:
		hud.set_boss_health(int(boss.get("hp")), int(boss.get("max_hp")))

func _debug_status_text() -> String:
	var fx := 0
	var nodes := get_tree().get_nodes_in_group("effects")
	fx = nodes.size()
	var proj := get_tree().get_nodes_in_group("projectiles").size()
	return "Enemies: %d   •   Projectiles: %d   •   FX: %d" % [get_enemy_count(), proj, fx]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		# Debug: E spawns an enemy, F triggers rapid-fire power-up.
		if k == KEY_E:
			if spawn_manager != null and running:
				spawn_manager.spawn_enemy()
				get_viewport().set_input_as_handled()
		elif k == KEY_F:
			_trigger_rapid_fire()
		elif k == KEY_F1:
			_switch_weapon("machinegun")
		elif k == KEY_F2:
			_switch_weapon("minigun")
		elif k == KEY_F3:
			_switch_weapon("rocket")
		elif k == KEY_F4:
			_trigger_laser()
		elif k == KEY_F5:
			_trigger_boss()
		elif k == KEY_F6:
			_trigger_rapid_fire()
		elif k == KEY_F7:
			if player != null and running:
				player.restore_default_weapon()
				if hud != null:
					hud.show_powerup_message("DEFAULT GUN")
				get_viewport().set_input_as_handled()
		elif k == KEY_R:
			# Quick keyboard restart once the game is over (button also works).
			if not running:
				restart_game()
				get_viewport().set_input_as_handled()

func _switch_weapon(weapon_id: String) -> void:
	if player == null or not running:
		return
	if player.set_weapon(weapon_id):
		if hud != null:
			hud.show_powerup_message(player.get_weapon_name().to_upper())
		get_viewport().set_input_as_handled()

func _trigger_rapid_fire() -> void:
	if player == null or not running:
		return
	player.activate_rapid_fire()
	if hud != null:
		hud.show_powerup_message("RAPID FIRE! (5s)")
	get_viewport().set_input_as_handled()

func _trigger_laser() -> void:
	if player == null or not running:
		return
	if player.fire_mega_laser():
		if hud != null:
			hud.show_powerup_message("MEGA LASER!")
	else:
		if hud != null:
			hud.show_powerup_message("LASER CHARGING... (%.1fs)" % player.get_laser_cooldown_left())
	get_viewport().set_input_as_handled()

func _trigger_boss() -> void:
	if spawn_manager == null or not running:
		return
	if spawn_manager.has_boss():
		if hud != null:
			hud.show_powerup_message("BOSS ALREADY ACTIVE!")
		get_viewport().set_input_as_handled()
		return
	var boss := spawn_manager.spawn_boss()
	if boss != null and hud != null:
		hud.show_powerup_message("WARNING: BOSS INCOMING!")
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

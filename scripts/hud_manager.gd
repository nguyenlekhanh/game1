class_name HUDManager
extends CanvasLayer

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var health_label: Label = $TopBar/HealthLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var time_label: Label = $TopBar/TimeLabel
@onready var enemy_label: Label = $TopBar/EnemyLabel
@onready var spawn_label: Label = $TopBar/SpawnLabel
@onready var powerup_label: Label = $PowerupLabel
@onready var weapon_label: Label = $SubBar/WeaponLabel
@onready var ability_label: Label = $SubBar/AbilityLabel
@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_bar: ProgressBar = $BossPanel/Margin/BossVBox/BossBar
@onready var debug_label: Label = $DebugLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/Margin/VBox/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/Margin/VBox/RestartButton
@onready var hint_label: Label = $HintLabel

var _powerup_timer: float = 0.0

func _ready() -> void:
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if powerup_label != null:
		powerup_label.visible = false
	set_game_over_visible(false)
	set_boss_visible(false)

func _process(delta: float) -> void:
	if _powerup_timer > 0.0:
		_powerup_timer -= delta
		if _powerup_timer <= 0.0 and powerup_label != null:
			powerup_label.visible = false

func set_health(current: int, maximum: int) -> void:
	if health_bar != null:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label != null:
		health_label.text = "HP: %d/%d" % [current, maximum]

func set_score(score: int) -> void:
	if score_label != null:
		score_label.text = "SCORE: %d" % score

func set_time(elapsed: float) -> void:
	if time_label != null:
		var m := int(elapsed) / 60
		var s := int(elapsed) % 60
		time_label.text = "TIME: %02d:%02d" % [m, s]

func set_enemy_count(count: int) -> void:
	if enemy_label != null:
		enemy_label.text = "ENEMIES: %d" % count

func set_spawn_interval(interval: float) -> void:
	if spawn_label != null:
		spawn_label.text = "SPAWN: %.2fs" % interval

func set_weapon(weapon_name: String) -> void:
	if weapon_label != null:
		weapon_label.text = "GUN: %s" % weapon_name

func set_abilities(text: String) -> void:
	if ability_label != null:
		ability_label.text = text

func set_boss_visible(v: bool) -> void:
	if boss_panel != null:
		boss_panel.visible = v

func set_boss_health(current: int, maximum: int) -> void:
	set_boss_visible(true)
	if boss_bar != null:
		boss_bar.max_value = maxi(1, maximum)
		boss_bar.value = maxi(0, current)

func set_boss_enraged(enraged: bool) -> void:
	# Clear ENRAGED indicator: red-tinted boss bar while enraged.
	if boss_bar != null:
		boss_bar.modulate = Color(1.0, 0.35, 0.3) if enraged else Color.WHITE

func set_debug_status(text: String) -> void:
	if debug_label != null:
		debug_label.text = text

func show_powerup_message(text: String, duration: float = 2.5) -> void:
	if powerup_label == null:
		return
	powerup_label.text = text
	powerup_label.visible = true
	_powerup_timer = duration

func show_game_over(score: int, elapsed: float) -> void:
	set_game_over_visible(true)
	if final_score_label != null:
		var m := int(elapsed) / 60
		var s := int(elapsed) % 60
		final_score_label.text = "Score: %d   •   Survived %02d:%02d" % [score, m, s]
	if restart_button != null:
		restart_button.grab_focus()

func set_game_over_visible(v: bool) -> void:
	if game_over_panel != null:
		game_over_panel.visible = v

func _on_restart_pressed() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("restart_game"):
		gm.restart_game()
	else:
		get_tree().reload_current_scene()

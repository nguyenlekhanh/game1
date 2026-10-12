class_name EnemyBullet
extends Area2D

## Boss energy projectile. Mirrors the Bullet conventions:
## finite lifetime + bounds cleanup, capped impact FX.
## Layer 2 / mask 1 so it hits the player (layer 1) and ignores enemies.
## Joins "bullets" (cleared on game over / restart path) and
## "enemy_shots" (cleared when the owning boss dies). Deliberately NOT
## in "projectiles" so boss shots never eat the player's projectile cap.

var velocity: Vector2 = Vector2.RIGHT
var speed: float = 330.0
var damage: int = 8
var life_time: float = 2.5
var age: float = 0.0
var radius: float = 8.0
var _dead: bool = false

static func create(start_pos: Vector2, direction: Vector2, bullet_damage: int = 8, bullet_speed: float = 330.0) -> EnemyBullet:
	var b := EnemyBullet.new()
	b.position = start_pos
	b.velocity = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	b.damage = bullet_damage
	b.speed = bullet_speed
	b.collision_layer = 2
	b.collision_mask = 1
	b.monitoring = true
	b.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	b.add_child(shape)
	b.body_entered.connect(b._on_body_entered)
	return b

func _ready() -> void:
	add_to_group("bullets")
	add_to_group("enemy_shots")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	age += delta
	if age >= life_time:
		queue_free()
		return
	position += velocity * speed * delta
	if position.x < -80.0 or position.x > 1360.0 or position.y < -80.0 or position.y > 800.0:
		queue_free()
		return
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_impact()
		queue_free()

func _spawn_impact() -> void:
	var fx_container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if fx_container == null:
		return
	if not Explosion.can_spawn_fx(get_tree()):
		return
	fx_container.add_child(Explosion.create(global_position, Color(1.0, 0.5, 0.1), 20.0))

func _draw() -> void:
	# Hot orange orb with glow: readable against the dark arena.
	var flick := 0.75 + 0.25 * sin(age * 25.0)
	draw_circle(Vector2.ZERO, radius + 6.0, Color(1.0, 0.45, 0.1, 0.30 * flick))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.12))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.95, 0.8))

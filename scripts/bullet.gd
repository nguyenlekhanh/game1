class_name Bullet
extends Area2D

signal hit_enemy

var velocity: Vector2 = Vector2.RIGHT
var speed: float = 750.0
var damage: int = 1
var life_time: float = 2.0
var age: float = 0.0
var radius: float = 6.0

static func create(start_pos: Vector2, direction: Vector2, bullet_damage: int = 1, bullet_speed: float = 750.0, bullet_radius: float = 6.0) -> Bullet:
	var b := Bullet.new()
	b.position = start_pos
	b.velocity = direction.normalized()
	b.damage = bullet_damage
	b.speed = bullet_speed
	b.radius = bullet_radius
	b.collision_layer = 4
	b.collision_mask = 2
	b.monitoring = true
	b.monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(3.0, bullet_radius)
	shape.shape = circle
	b.add_child(shape)
	# Connect after entering tree; caller also connects. Safe-guard here:
	b.body_entered.connect(b._on_body_entered)
	b.area_entered.connect(b._on_area_entered)
	return b

func _ready() -> void:
	add_to_group("bullets")
	add_to_group("projectiles")
	# If created via create(), signals are already connected.
	# If created via .new() + add_child path, ensure connections exist.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= life_time:
		queue_free()
		return
	position += velocity * speed * delta
	# Hard arena + margin cleanup so bullets never accumulate forever.
	if position.x < -80.0 or position.x > 1360.0 or position.y < -80.0 or position.y > 800.0:
		queue_free()
		return
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage, velocity)
		_spawn_impact()
		hit_enemy.emit()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and area.has_method("take_damage"):
		area.take_damage(damage, velocity)
		_spawn_impact()
		hit_enemy.emit()
		queue_free()

func _spawn_impact() -> void:
	# Small capped hit flash so minigun streams can't flood the renderer.
	var fx_container := get_tree().get_first_node_in_group("effect_container") as Node2D
	if fx_container == null:
		return
	if not Explosion.can_spawn_fx(get_tree()):
		return
	fx_container.add_child(Explosion.create(global_position, Color(1.0, 0.9, 0.4), 16.0))

func _draw() -> void:
	# Glowing bullet: outer glow + bright core + short trail.
	var trail_dir := -velocity.normalized() if velocity.length() > 0.01 else Vector2.LEFT
	draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.85, 0.2, 0.25))
	draw_line(trail_dir * 4.0, trail_dir * 20.0, Color(1.0, 0.8, 0.2, 0.8), 5.0, true)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.1))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 1.0, 0.9))

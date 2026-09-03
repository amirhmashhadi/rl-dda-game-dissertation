class_name Projectile
extends Area2D

# Remove projectiles that stay in the scene for too long.
const MAX_LIFETIME := 5.0

# Current projectile settings.
var damage := 10.0
var direction := Vector2.RIGHT
var speed := 200.0

# Tracks how long the projectile has existed.
var _lifetime := 0.0


func _ready() -> void:
	# Add the projectile to a group so the simulated player can detect it.
	add_to_group("projectile")

	# Detect collisions with bodies such as the simulated player.
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Move the projectile in its current direction.
	global_position += direction * speed * delta

	# Track lifetime and remove old projectiles.
	_lifetime += delta

	if _lifetime >= MAX_LIFETIME:
		queue_free()


func setup(
	new_direction: Vector2,
	new_speed: float,
	new_damage: float
) -> void:
	# Apply the values provided by the turret when the projectile is created.
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage


func _on_body_entered(body: Node) -> void:
	# Damage valid targets and remove the projectile after impact.
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

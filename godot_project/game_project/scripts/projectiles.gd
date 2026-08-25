class_name Projectile
extends Area2D

const MAX_LIFETIME := 5.0

var damage := 10.0
var direction := Vector2.RIGHT
var speed := 200.0

var _lifetime := 0.0


func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime += delta

	if _lifetime >= MAX_LIFETIME:
		queue_free()


func setup(new_direction: Vector2, new_speed: float, new_damage: float) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

class_name EnemyTurret
extends Node2D

const MAX_DIFFICULTY_LEVEL := 10

@export var max_damage := 18.0
@export var max_fire_interval := 1.4
@export var max_projectile_speed := 420.0
@export var max_spread_degrees := 25.0
@export var min_damage := 5.0
@export var min_fire_interval := 0.35
@export var min_projectile_speed := 150.0
@export var min_spread_degrees := 2.0
@export var projectile_scene: PackedScene
@export var projectiles_path: NodePath = "../Projectiles"
@export var target_path: NodePath = "../SimulatedPlayer"

var damage := 10.0
var fire_interval := 1.0
var projectile_speed := 250.0
var shot_spread_degrees := 10.0

var _is_active := false
var _shoot_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var projectile_spawn_point: Marker2D = $ProjectileSpawnPoint
@onready var projectiles: Node2D = get_node(projectiles_path) as Node2D
@onready var target: SimulatedPlayer = get_node(target_path) as SimulatedPlayer


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	if target == null or target.is_dead():
		return

	_shoot_timer -= delta

	if _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = fire_interval


func apply_difficulty(difficulty_level: int) -> void:
	var difficulty_ratio := float(clampi(difficulty_level, 0, MAX_DIFFICULTY_LEVEL)) / float(MAX_DIFFICULTY_LEVEL)

	projectile_speed = lerpf(min_projectile_speed, max_projectile_speed, difficulty_ratio)
	fire_interval = lerpf(max_fire_interval, min_fire_interval, difficulty_ratio)
	damage = lerpf(min_damage, max_damage, difficulty_ratio)
	shot_spread_degrees = lerpf(max_spread_degrees, min_spread_degrees, difficulty_ratio)


func set_active(value: bool) -> void:
	_is_active = value
	_shoot_timer = fire_interval


func _shoot() -> void:
	if projectile_scene == null:
		push_warning("Projectile scene is not assigned.")
		return

	var projectile := projectile_scene.instantiate() as Projectile

	if projectile == null:
		return

	var direction := global_position.direction_to(target.global_position)
	var spread := deg_to_rad(_rng.randf_range(-shot_spread_degrees, shot_spread_degrees))

	projectile.global_position = projectile_spawn_point.global_position
	projectile.setup(direction.rotated(spread), projectile_speed, damage)

	projectiles.add_child(projectile)

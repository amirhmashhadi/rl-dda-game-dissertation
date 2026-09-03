class_name EnemyTurret
extends Node2D

# Difficulty reference points used when scaling turret settings.
const MAX_DIFFICULTY_LEVEL := 10
const NORMAL_DIFFICULTY_LEVEL := 5

@export_group("Projectile Settings")

# Projectile scene and scene references used by the turret.
@export var projectile_scene: PackedScene
@export var projectiles_path: NodePath = "../Projectiles"
@export var target_path: NodePath = "../SimulatedPlayer"

@export_group("Projectile Speed")

# Projectile speeds for easy, normal, and hard difficulty.
@export var easiest_projectile_speed := 150.0
@export var normal_projectile_speed := 220.0
@export var hardest_projectile_speed := 360.0

@export_group("Fire Rate")

# Time between shots for each main difficulty level.
@export var easiest_fire_interval := 1.4
@export var normal_fire_interval := 1.18
@export var hardest_fire_interval := 0.55

@export_group("Damage")

# Projectile damage for each main difficulty level.
@export var easiest_damage := 5.0
@export var normal_damage := 8.5
@export var hardest_damage := 14.0

@export_group("Accuracy")

# Maximum random shot spread for each main difficulty level.
@export var easiest_spread_degrees := 25.0
@export var normal_spread_degrees := 19.0
@export var hardest_spread_degrees := 6.0

# Current turret settings.
var damage := normal_damage
var fire_interval := normal_fire_interval
var projectile_speed := normal_projectile_speed
var shot_spread_degrees := normal_spread_degrees

# Controls firing and shot timing.
var _is_active := false
var _shoot_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var projectile_spawn_point: Marker2D = $ProjectileSpawnPoint
@onready var projectiles: Node2D = get_node(projectiles_path) as Node2D
@onready var target: SimulatedPlayer = get_node(target_path) as SimulatedPlayer


func _ready() -> void:
	# Randomise shot spread values between runs.
	_rng.randomize()


func _physics_process(delta: float) -> void:
	# Do not fire while the turret is inactive.
	if not _is_active:
		return

	# Stop firing if there is no valid living target.
	if target == null or target.is_dead():
		return

	# Count down until the next shot.
	_shoot_timer -= delta

	if _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = fire_interval


func apply_difficulty(difficulty_level: int) -> void:
	# Keep the requested difficulty within the valid range.
	var clamped_level := clampi(
		difficulty_level,
		0,
		MAX_DIFFICULTY_LEVEL
	)

	if clamped_level <= NORMAL_DIFFICULTY_LEVEL:
		# Scale settings between easiest and normal difficulty.
		var ratio := (
			float(clamped_level)
			/ float(NORMAL_DIFFICULTY_LEVEL)
		)

		projectile_speed = lerpf(
			easiest_projectile_speed,
			normal_projectile_speed,
			ratio
		)

		fire_interval = lerpf(
			easiest_fire_interval,
			normal_fire_interval,
			ratio
		)

		damage = lerpf(
			easiest_damage,
			normal_damage,
			ratio
		)

		shot_spread_degrees = lerpf(
			easiest_spread_degrees,
			normal_spread_degrees,
			ratio
		)
	else:
		# Scale settings between normal and hardest difficulty.
		var ratio := (
			float(clamped_level - NORMAL_DIFFICULTY_LEVEL)
			/ float(MAX_DIFFICULTY_LEVEL - NORMAL_DIFFICULTY_LEVEL)
		)

		projectile_speed = lerpf(
			normal_projectile_speed,
			hardest_projectile_speed,
			ratio
		)

		fire_interval = lerpf(
			normal_fire_interval,
			hardest_fire_interval,
			ratio
		)

		damage = lerpf(
			normal_damage,
			hardest_damage,
			ratio
		)

		shot_spread_degrees = lerpf(
			normal_spread_degrees,
			hardest_spread_degrees,
			ratio
		)


func set_active(value: bool) -> void:
	# Enable or disable the turret and reset its firing timer.
	_is_active = value
	_shoot_timer = fire_interval


func _shoot() -> void:
	# Prevent shooting if no projectile scene has been assigned.
	if projectile_scene == null:
		push_warning("Projectile scene is not assigned.")
		return

	var projectile := projectile_scene.instantiate() as Projectile

	if projectile == null:
		return

	# Aim at the player and apply a random spread based on difficulty.
	var direction := global_position.direction_to(target.global_position)
	var spread := deg_to_rad(
		_rng.randf_range(
			-shot_spread_degrees,
			shot_spread_degrees
		)
	)

	# Spawn and configure the projectile.
	projectile.global_position = projectile_spawn_point.global_position
	projectile.setup(
		direction.rotated(spread),
		projectile_speed,
		damage
	)

	projectiles.add_child(projectile)

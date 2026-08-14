class_name SimulatedPlayer
extends CharacterBody2D

signal died

const DEFAULT_HEALTH := 100.0
const SCORE_PER_SECOND := 10.0

@export var arena_half_size := Vector2(480.0, 270.0)
@export var dodge_chance := 0.55
@export var dodge_duration := 0.75
@export var mistake_chance := 0.18
@export var movement_speed := 160.0
@export var profile_name := "intermediate"
@export var reaction_time := 0.35
@export var retreat_weight := 0.35
@export var strafe_weight := 0.75
@export var threat_detection_radius := 180.0

var deaths := 0
var health := DEFAULT_HEALTH
var hits_taken := 0
var score := 0
var survival_time := 0.0

var _current_direction := Vector2.RIGHT
var _dodge_time_left := 0.0
var _is_dead := false
var _reaction_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	survival_time += delta
	score = int(survival_time * SCORE_PER_SECOND)

	if _dodge_time_left > 0.0:
		_dodge_time_left -= delta
	else:
		_reaction_timer += delta

		if _reaction_timer >= reaction_time:
			_current_direction = _choose_move_direction()
			_reaction_timer = 0.0

	velocity = _current_direction * movement_speed
	move_and_slide()

	_clamp_to_arena()


func reset_player(spawn_position: Vector2) -> void:
	deaths = 0
	health = DEFAULT_HEALTH
	hits_taken = 0
	score = 0
	survival_time = 0.0

	_current_direction = Vector2.RIGHT
	_dodge_time_left = 0.0
	_is_dead = false
	_reaction_timer = 0.0

	global_position = spawn_position
	velocity = Vector2.ZERO


func take_damage(amount: float) -> void:
	if _is_dead:
		return

	health -= amount
	hits_taken += 1

	if health <= 0.0:
		_die()


func is_dead() -> bool:
	return _is_dead


func get_health_remaining() -> float:
	return maxf(health, 0.0)


func _choose_move_direction() -> Vector2:
	if _rng.randf() < mistake_chance:
		return _get_random_direction()

	var nearest_projectile := _get_nearest_projectile()

	if nearest_projectile == null:
		return _get_random_direction()

	if _rng.randf() > dodge_chance:
		return _get_random_direction()

	_dodge_time_left = dodge_duration

	return _get_dodge_direction(nearest_projectile)


func _get_nearest_projectile() -> Projectile:
	var nearest_projectile: Projectile = null
	var nearest_distance := threat_detection_radius

	for node in get_tree().get_nodes_in_group("projectile"):
		var projectile := node as Projectile

		if projectile == null:
			continue

		var distance := global_position.distance_to(projectile.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_projectile = projectile

	return nearest_projectile


func _get_dodge_direction(projectile: Projectile) -> Vector2:
	var projectile_direction := projectile.direction.normalized()

	if projectile_direction.length() <= 0.01:
		projectile_direction = projectile.global_position.direction_to(global_position)

	var away_direction := projectile.global_position.direction_to(global_position).normalized()
	var left_strafe := projectile_direction.orthogonal().normalized()
	var right_strafe := -left_strafe

	var left_dodge := ((left_strafe * strafe_weight) + (away_direction * retreat_weight)).normalized()
	var right_dodge := ((right_strafe * strafe_weight) + (away_direction * retreat_weight)).normalized()

	return _choose_safer_dodge(left_dodge, right_dodge)


func _choose_safer_dodge(left_dodge: Vector2, right_dodge: Vector2) -> Vector2:
	var left_position := global_position + left_dodge * movement_speed * dodge_duration
	var right_position := global_position + right_dodge * movement_speed * dodge_duration

	var left_margin := _get_arena_margin(left_position)
	var right_margin := _get_arena_margin(right_position)

	if absf(left_margin - right_margin) < 5.0:
		if _rng.randf() < 0.5:
			return left_dodge

		return right_dodge

	if left_margin > right_margin:
		return left_dodge

	return right_dodge


func _get_arena_margin(target_position: Vector2) -> float:
	var x_margin := arena_half_size.x - absf(target_position.x)
	var y_margin := arena_half_size.y - absf(target_position.y)

	return minf(x_margin, y_margin)


func _get_random_direction() -> Vector2:
	var random_direction := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)

	if random_direction.length() <= 0.01:
		return Vector2.RIGHT

	return random_direction.normalized()


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -arena_half_size.x, arena_half_size.x)
	global_position.y = clampf(global_position.y, -arena_half_size.y, arena_half_size.y)


func _die() -> void:
	_is_dead = true
	deaths += 1
	velocity = Vector2.ZERO
	died.emit()

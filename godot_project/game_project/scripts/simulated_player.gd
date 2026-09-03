class_name SimulatedPlayer
extends CharacterBody2D

signal died

# Base values used for every simulated player.
const DEFAULT_HEALTH := 100.0
const SCORE_PER_SECOND := 10.0

# Fixed behaviour settings for the main player profiles.
const PROFILE_STATS := {
	"beginner": {
		"movement_speed": 130.0,
		"reaction_time": 0.70,
		"dodge_chance": 0.28,
		"mistake_chance": 0.45,
		"threat_detection_radius": 120.0,
		"dodge_duration": 0.55,
		"strafe_weight": 0.60,
		"retreat_weight": 0.20
	},
	"intermediate": {
		"movement_speed": 170.0,
		"reaction_time": 0.30,
		"dodge_chance": 0.65,
		"mistake_chance": 0.15,
		"threat_detection_radius": 220.0,
		"dodge_duration": 0.85,
		"strafe_weight": 0.75,
		"retreat_weight": 0.35
	},
	"skilled": {
		"movement_speed": 195.0,
		"reaction_time": 0.20,
		"dodge_chance": 0.85,
		"mistake_chance": 0.06,
		"threat_detection_radius": 260.0,
		"dodge_duration": 0.95,
		"strafe_weight": 0.85,
		"retreat_weight": 0.40
	}
}

# Defines the movement boundaries of the arena.
@export var arena_half_size := Vector2(480.0, 270.0)

# Selects which simulated behaviour profile is used.
@export_enum("beginner", "intermediate", "skilled", "inconsistent", "improving")
var selected_profile := "intermediate"

var profile_name := "intermediate"

# Current behaviour settings for the active profile.
var dodge_chance := 0.65
var dodge_duration := 0.85
var mistake_chance := 0.15
var movement_speed := 170.0
var reaction_time := 0.30
var retreat_weight := 0.35
var strafe_weight := 0.75
var threat_detection_radius := 220.0

# Gameplay statistics recorded during each episode.
var deaths := 0
var health := DEFAULT_HEALTH
var hits_taken := 0
var score := 0
var survival_time := 0.0

# Internal movement and decision state.
var _current_direction := Vector2.RIGHT
var _dodge_time_left := 0.0
var _is_dead := false
var _reaction_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Initialise random behaviour and apply the selected profile.
	_rng.randomize()
	_apply_profile_for_run(1, 1)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Update survival time and score while the player is alive.
	survival_time += delta
	score = int(survival_time * SCORE_PER_SECOND)

	# Keep the current dodge direction until its duration ends.
	if _dodge_time_left > 0.0:
		_dodge_time_left -= delta
	else:
		# Reconsider movement when the profile's reaction timer expires.
		_reaction_timer += delta

		if _reaction_timer >= reaction_time:
			_current_direction = _choose_move_direction()
			_reaction_timer = 0.0

	# Move using the direction chosen by the simulated behaviour.
	velocity = _current_direction * movement_speed
	move_and_slide()

	# Prevent the player from leaving the arena.
	_clamp_to_arena()


func reset_player(
	spawn_position: Vector2,
	run_number := 1,
	total_runs := 1
) -> void:
	# Apply the correct profile settings for this run.
	_apply_profile_for_run(run_number, total_runs)

	# Reset gameplay statistics.
	deaths = 0
	health = DEFAULT_HEALTH
	hits_taken = 0
	score = 0
	survival_time = 0.0

	# Reset movement and decision state.
	_current_direction = Vector2.RIGHT
	_dodge_time_left = 0.0
	_is_dead = false
	_reaction_timer = 0.0

	global_position = spawn_position
	velocity = Vector2.ZERO


func take_damage(amount: float) -> void:
	# Ignore damage after the player has already died.
	if _is_dead:
		return

	health -= amount
	hits_taken += 1

	if health <= 0.0:
		_die()


func is_dead() -> bool:
	# Return whether the simulated player has died.
	return _is_dead


func get_health_remaining() -> float:
	# Prevent health values below zero from being reported.
	return maxf(health, 0.0)


func _apply_profile_for_run(
	run_number: int,
	total_runs: int
) -> void:
	# Apply the selected fixed or changing behaviour profile.
	match selected_profile:
		"beginner":
			profile_name = "beginner"
			_apply_stats(PROFILE_STATS["beginner"])

		"intermediate":
			profile_name = "intermediate"
			_apply_stats(PROFILE_STATS["intermediate"])

		"skilled":
			profile_name = "skilled"
			_apply_stats(PROFILE_STATS["skilled"])

		"inconsistent":
			profile_name = "inconsistent"
			_apply_inconsistent_stats()

		"improving":
			profile_name = "improving"
			_apply_improving_stats(run_number, total_runs)

		_:
			# Fall back to the intermediate profile if the value is invalid.
			profile_name = "intermediate"
			_apply_stats(PROFILE_STATS["intermediate"])


func _apply_stats(stats: Dictionary) -> void:
	# Copy behaviour values from a fixed profile into the active player.
	movement_speed = float(stats["movement_speed"])
	reaction_time = float(stats["reaction_time"])
	dodge_chance = float(stats["dodge_chance"])
	mistake_chance = float(stats["mistake_chance"])
	threat_detection_radius = float(stats["threat_detection_radius"])
	dodge_duration = float(stats["dodge_duration"])
	strafe_weight = float(stats["strafe_weight"])
	retreat_weight = float(stats["retreat_weight"])


func _apply_inconsistent_stats() -> void:
	# Randomise behaviour each run to represent an inconsistent player.
	movement_speed = _rng.randf_range(135.0, 195.0)
	reaction_time = _rng.randf_range(0.20, 0.65)
	dodge_chance = _rng.randf_range(0.35, 0.85)
	mistake_chance = _rng.randf_range(0.06, 0.40)
	threat_detection_radius = _rng.randf_range(145.0, 260.0)
	dodge_duration = _rng.randf_range(0.60, 0.95)
	strafe_weight = _rng.randf_range(0.60, 0.85)
	retreat_weight = _rng.randf_range(0.20, 0.45)


func _apply_improving_stats(
	run_number: int,
	total_runs: int
) -> void:
	# Calculate progression from beginner to skilled across all runs.
	var progress := 0.0

	if total_runs > 1:
		progress = float(run_number - 1) / float(total_runs - 1)

	var beginner_stats := PROFILE_STATS["beginner"]
	var skilled_stats := PROFILE_STATS["skilled"]

	# Gradually move each behaviour value from beginner to skilled.
	movement_speed = lerpf(
		float(beginner_stats["movement_speed"]),
		float(skilled_stats["movement_speed"]),
		progress
	)

	reaction_time = lerpf(
		float(beginner_stats["reaction_time"]),
		float(skilled_stats["reaction_time"]),
		progress
	)

	dodge_chance = lerpf(
		float(beginner_stats["dodge_chance"]),
		float(skilled_stats["dodge_chance"]),
		progress
	)

	mistake_chance = lerpf(
		float(beginner_stats["mistake_chance"]),
		float(skilled_stats["mistake_chance"]),
		progress
	)

	threat_detection_radius = lerpf(
		float(beginner_stats["threat_detection_radius"]),
		float(skilled_stats["threat_detection_radius"]),
		progress
	)

	dodge_duration = lerpf(
		float(beginner_stats["dodge_duration"]),
		float(skilled_stats["dodge_duration"]),
		progress
	)

	strafe_weight = lerpf(
		float(beginner_stats["strafe_weight"]),
		float(skilled_stats["strafe_weight"]),
		progress
	)

	retreat_weight = lerpf(
		float(beginner_stats["retreat_weight"]),
		float(skilled_stats["retreat_weight"]),
		progress
	)


func _choose_move_direction() -> Vector2:
	# Occasionally make a random movement mistake.
	if _rng.randf() < mistake_chance:
		return _get_random_direction()

	# Find the nearest projectile inside the detection radius.
	var nearest_projectile := _get_nearest_projectile()

	if nearest_projectile == null:
		return _get_random_direction()

	# Fail to dodge if the profile's dodge attempt is unsuccessful.
	if _rng.randf() > dodge_chance:
		return _get_random_direction()

	# Commit to the chosen dodge direction for a short period.
	_dodge_time_left = dodge_duration

	return _get_dodge_direction(nearest_projectile)


func _get_nearest_projectile() -> Projectile:
	# Search for the closest projectile inside the threat detection radius.
	var nearest_projectile: Projectile = null
	var nearest_distance := threat_detection_radius

	for node in get_tree().get_nodes_in_group("projectile"):
		var projectile := node as Projectile

		if projectile == null:
			continue

		var distance := global_position.distance_to(
			projectile.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_projectile = projectile

	return nearest_projectile


func _get_dodge_direction(projectile: Projectile) -> Vector2:
	# Get the direction the projectile is travelling.
	var projectile_direction := projectile.direction.normalized()

	if projectile_direction.length() <= 0.01:
		projectile_direction = projectile.global_position.direction_to(
			global_position
		)

	# Calculate a direction away from the projectile.
	var away_direction := projectile.global_position.direction_to(
		global_position
	).normalized()

	if away_direction.length() <= 0.01:
		away_direction = _get_random_direction()

	# Create left and right strafe directions relative to the projectile.
	var left_strafe := projectile_direction.orthogonal().normalized()
	var right_strafe := -left_strafe

	# Combine sideways movement with movement away from danger.
	var left_dodge := (
		(left_strafe * strafe_weight)
		+ (away_direction * retreat_weight)
	).normalized()

	var right_dodge := (
		(right_strafe * strafe_weight)
		+ (away_direction * retreat_weight)
	).normalized()

	return _choose_safer_dodge(left_dodge, right_dodge)


func _choose_safer_dodge(
	left_dodge: Vector2,
	right_dodge: Vector2
) -> Vector2:
	# Predict where each dodge direction would move the player.
	var left_position := (
		global_position
		+ left_dodge * movement_speed * dodge_duration
	)

	var right_position := (
		global_position
		+ right_dodge * movement_speed * dodge_duration
	)

	# Prefer the direction that leaves more space from the arena boundary.
	var left_margin := _get_arena_margin(left_position)
	var right_margin := _get_arena_margin(right_position)

	# Randomly choose if both directions are almost equally safe.
	if absf(left_margin - right_margin) < 5.0:
		if _rng.randf() < 0.5:
			return left_dodge

		return right_dodge

	if left_margin > right_margin:
		return left_dodge

	return right_dodge


func _get_arena_margin(target_position: Vector2) -> float:
	# Measure the remaining space between a position and the nearest arena edge.
	var x_margin := arena_half_size.x - absf(target_position.x)
	var y_margin := arena_half_size.y - absf(target_position.y)

	return minf(x_margin, y_margin)


func _get_random_direction() -> Vector2:
	# Generate a random movement direction.
	var random_direction := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)

	if random_direction.length() <= 0.01:
		return Vector2.RIGHT

	return random_direction.normalized()


func _clamp_to_arena() -> void:
	# Keep the player inside the arena boundaries.
	global_position.x = clampf(
		global_position.x,
		-arena_half_size.x,
		arena_half_size.x
	)

	global_position.y = clampf(
		global_position.y,
		-arena_half_size.y,
		arena_half_size.y
	)


func _die() -> void:
	# Mark the player as dead and notify the experiment manager.
	_is_dead = true
	deaths += 1
	velocity = Vector2.ZERO
	died.emit()

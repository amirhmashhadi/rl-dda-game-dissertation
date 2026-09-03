class_name ExperimentManager
extends Node2D

# Output file and experiment mode settings.
@export_file("*.csv") var results_file_path := "res://data/raw/rl_training_reward_fixed_1.csv"
@export_range(0, 10, 1) var static_difficulty_level := 5
@export_enum("static", "rule_based", "rl_based") var system_name := "rl_based"

# General experiment timing settings.
@export var episode_duration := 60.0
@export var max_runs := 300
@export var reset_delay := 1.0
@export var simulation_speed := 5.0

@export_group("Target Range")

# Health range used to measure time spent in the target balance zone.
@export var player_max_health := 100.0
@export var target_min_health_percentage := 30.0
@export var target_max_health_percentage := 80.0

@export_group("Training Profile Randomisation")

# Randomises the simulated player profile during RL training.
@export var randomise_profile_each_run := true
@export var random_training_profiles: PackedStringArray = [
	"beginner",
	"intermediate",
	"skilled",
	"inconsistent"
]

@export_group("RL Initial Difficulty Randomisation")

# Randomises the starting difficulty during RL training.
@export var randomise_initial_difficulty_each_run := true
@export_range(0, 10, 1) var random_initial_min_difficulty := 3
@export_range(0, 10, 1) var random_initial_max_difficulty := 7

# Tracks the current experiment run and elapsed episode time.
var _episode_time := 0.0
var _is_running := false
var _run_number := 0

# Tracks difficulty behaviour during each episode.
var _initial_difficulty := 0
var _min_difficulty := 0
var _max_difficulty := 0
var _difficulty_changes := 0
var _last_difficulty_level := -1
var _difficulty_time_sum := 0.0
var _difficulty_tracking_time := 0.0

# Tracks how long the player remains inside the target health range.
var _time_in_target_range := 0.0

var _rng := RandomNumberGenerator.new()

# References to the main experiment systems.
@onready var difficulty_manager: DifficultyManager = $DifficultyManager
@onready var enemy_turret: EnemyTurret = $EnemyTurret
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var projectiles: Node2D = $Projectiles
@onready var simulated_player: SimulatedPlayer = $SimulatedPlayer
@onready var rule_based_dda: RuleBasedDDA = get_node_or_null("RuleBasedDDA") as RuleBasedDDA
@onready var dda_ai_controller: DDAAIController = get_node_or_null("DDAAIController") as DDAAIController


func _ready() -> void:
	# Initialise randomness and speed up the simulation.
	_rng.randomize()
	Engine.time_scale = simulation_speed

	# Listen for difficulty changes and player deaths.
	difficulty_manager.difficulty_changed.connect(_on_difficulty_changed)
	simulated_player.died.connect(_on_simulated_player_died)

	# Create the results file and begin the experiment.
	_prepare_results_file()
	_start_run()


func _process(delta: float) -> void:
	if not _is_running:
		return

	# Update episode timing and tracked metrics.
	_episode_time += delta
	_update_difficulty_tracking(delta)
	_update_target_range_time(delta)

	# End the episode when the time limit is reached.
	if _episode_time >= episode_duration:
		_finish_run(false)


func _start_run() -> void:
	# Stop the experiment when the requested number of runs is complete.
	if _run_number >= max_runs:
		enemy_turret.set_active(false)
		Engine.time_scale = 1.0

		print(
			"Experiment complete. Results saved to: ",
			ProjectSettings.globalize_path(results_file_path)
		)
		return

	# Reset basic run state.
	_run_number += 1
	_episode_time = 0.0
	_is_running = true

	# Clear objects left over from the previous episode.
	_clear_projectiles()

	# Select a training profile if randomisation is enabled.
	_choose_random_training_profile()

	# Reset the simulated player at the spawn point.
	simulated_player.reset_player(
		player_spawn.global_position,
		_run_number,
		max_runs
	)

	# Choose and apply the starting difficulty.
	var starting_difficulty := _get_starting_difficulty()

	_reset_difficulty_tracking(starting_difficulty)
	difficulty_manager.set_difficulty_level(starting_difficulty)

	# Enable rule-based DDA only when that system is being tested.
	if _is_rule_based_system() and rule_based_dda != null:
		rule_based_dda.reset()
		rule_based_dda.set_active(true)
	elif rule_based_dda != null:
		rule_based_dda.set_active(false)

	# Reset RL controller state between episodes.
	if dda_ai_controller != null:
		dda_ai_controller.reset()

	# Start enemy attacks.
	enemy_turret.set_active(true)

	print(
		"Starting run ",
		_run_number,
		" | Profile: ",
		simulated_player.profile_name,
		" | Starting difficulty: ",
		starting_difficulty
	)


func _finish_run(player_died: bool) -> void:
	# Prevent the same episode from ending more than once.
	if not _is_running:
		return

	_is_running = false
	enemy_turret.set_active(false)

	if rule_based_dda != null:
		rule_based_dda.set_active(false)

	# Save the completed episode to the CSV file.
	_append_result(player_died)

	# Wait briefly before starting the next run.
	await get_tree().create_timer(reset_delay).timeout
	_start_run()


func _prepare_results_file() -> void:
	# Create a new CSV file and write its column headers.
	var file := FileAccess.open(results_file_path, FileAccess.WRITE)

	if file == null:
		push_error("Could not create results file: " + results_file_path)
		return

	file.store_csv_line(PackedStringArray([
		"profile_name",
		"system_name",
		"run_number",
		"player_died",
		"survival_time",
		"score",
		"health_remaining",
		"hits_taken",
		"deaths",
		"initial_difficulty",
		"final_difficulty",
		"average_difficulty",
		"min_difficulty",
		"max_difficulty",
		"difficulty_changes",
		"time_in_target_range",
		"target_range_percentage",
		"profile_speed",
		"profile_reaction_time",
		"profile_dodge_chance",
		"profile_mistake_chance",
		"profile_detection_radius",
		"profile_dodge_duration",
		"profile_strafe_weight",
		"profile_retreat_weight"
	]))


func _append_result(player_died: bool) -> void:
	# Open the results file and append one completed episode.
	var file := FileAccess.open(results_file_path, FileAccess.READ_WRITE)

	if file == null:
		push_error("Could not open results file: " + results_file_path)
		return

	# Clamp timing values so they cannot exceed the episode duration.
	var clamped_survival_time := minf(
		simulated_player.survival_time,
		episode_duration
	)

	var clamped_target_time := minf(
		_time_in_target_range,
		clamped_survival_time
	)

	var target_range_percentage := 0.0

	# Calculate the percentage of survival time spent in the target range.
	if clamped_survival_time > 0.0:
		target_range_percentage = (
			clamped_target_time / clamped_survival_time
		) * 100.0

	# Write gameplay, difficulty, and profile values to the CSV.
	file.seek_end()
	file.store_csv_line(PackedStringArray([
		simulated_player.profile_name,
		system_name,
		str(_run_number),
		str(player_died),
		str(snappedf(clamped_survival_time, 0.01)),
		str(simulated_player.score),
		str(snappedf(simulated_player.get_health_remaining(), 0.01)),
		str(simulated_player.hits_taken),
		str(simulated_player.deaths),
		str(_initial_difficulty),
		str(difficulty_manager.difficulty_level),
		str(snappedf(_get_average_difficulty(), 0.01)),
		str(_min_difficulty),
		str(_max_difficulty),
		str(_difficulty_changes),
		str(snappedf(clamped_target_time, 0.01)),
		str(snappedf(target_range_percentage, 0.01)),
		str(snappedf(simulated_player.movement_speed, 0.01)),
		str(snappedf(simulated_player.reaction_time, 0.01)),
		str(snappedf(simulated_player.dodge_chance, 0.01)),
		str(snappedf(simulated_player.mistake_chance, 0.01)),
		str(snappedf(simulated_player.threat_detection_radius, 0.01)),
		str(snappedf(simulated_player.dodge_duration, 0.01)),
		str(snappedf(simulated_player.strafe_weight, 0.01)),
		str(snappedf(simulated_player.retreat_weight, 0.01))
	]))


func _choose_random_training_profile() -> void:
	# Leave the selected profile unchanged when randomisation is disabled.
	if not randomise_profile_each_run:
		return

	if random_training_profiles.is_empty():
		return

	# Choose one of the allowed training profiles at random.
	var random_index := _rng.randi_range(
		0,
		random_training_profiles.size() - 1
	)

	var selected_training_profile := String(
		random_training_profiles[random_index]
	)

	simulated_player.selected_profile = selected_training_profile


func _get_starting_difficulty() -> int:
	# Static and rule-based systems always start from the configured baseline.
	if not _is_rl_based_system():
		return static_difficulty_level

	# Use the baseline for RL if randomisation is disabled.
	if not randomise_initial_difficulty_each_run:
		return static_difficulty_level

	# Choose a random RL starting difficulty inside the configured range.
	var min_level := mini(
		random_initial_min_difficulty,
		random_initial_max_difficulty
	)

	var max_level := maxi(
		random_initial_min_difficulty,
		random_initial_max_difficulty
	)

	return _rng.randi_range(min_level, max_level)


func _reset_difficulty_tracking(starting_difficulty: int) -> void:
	# Reset all per-episode difficulty metrics.
	_initial_difficulty = starting_difficulty
	_min_difficulty = starting_difficulty
	_max_difficulty = starting_difficulty
	_difficulty_changes = 0
	_last_difficulty_level = starting_difficulty
	_difficulty_time_sum = 0.0
	_difficulty_tracking_time = 0.0
	_time_in_target_range = 0.0


func _update_difficulty_tracking(delta: float) -> void:
	# Accumulate difficulty over time so an episode average can be calculated.
	_difficulty_time_sum += float(
		difficulty_manager.difficulty_level
	) * delta

	_difficulty_tracking_time += delta


func _update_target_range_time(delta: float) -> void:
	# Convert current health into a percentage.
	var health_percentage := 0.0

	if player_max_health > 0.0:
		health_percentage = (
			simulated_player.get_health_remaining()
			/ player_max_health
		) * 100.0

	# Count time spent inside the defined balance range.
	if (
		health_percentage >= target_min_health_percentage
		and health_percentage <= target_max_health_percentage
	):
		_time_in_target_range += delta


func _get_average_difficulty() -> float:
	# Return the time-weighted average difficulty for the episode.
	if _difficulty_tracking_time <= 0.0:
		return float(_initial_difficulty)

	return _difficulty_time_sum / _difficulty_tracking_time


func _clear_projectiles() -> void:
	# Remove projectiles left over from the previous episode.
	for child in projectiles.get_children():
		child.queue_free()


func _on_difficulty_changed(difficulty_level: int) -> void:
	# Apply the new difficulty settings to the turret.
	enemy_turret.apply_difficulty(difficulty_level)

	# Track the lowest and highest difficulty reached.
	_min_difficulty = mini(_min_difficulty, difficulty_level)
	_max_difficulty = maxi(_max_difficulty, difficulty_level)

	# Count actual changes in difficulty level.
	if difficulty_level != _last_difficulty_level:
		_difficulty_changes += 1
		_last_difficulty_level = difficulty_level


func _on_simulated_player_died() -> void:
	# End the current episode immediately when the player dies.
	_finish_run(true)


func _is_rule_based_system() -> bool:
	# Check whether the current experiment uses rule-based DDA.
	return system_name == "rule_based"


func _is_rl_based_system() -> bool:
	# Check whether the current experiment uses RL-based DDA.
	return system_name == "rl_based"

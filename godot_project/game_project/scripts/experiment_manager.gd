class_name ExperimentManager
extends Node2D

@export_file("*.csv") var results_file_path := "res://data/raw/static_difficulty_5_intermediate_logged.csv"
@export_range(0, 10, 1) var static_difficulty_level := 5
@export_enum("static", "rule_based", "rl_based") var system_name := "static"

@export var episode_duration := 60.0
@export var max_runs := 30
@export var reset_delay := 1.0
@export var simulation_speed := 5.0

@export_group("Target Range")
@export var player_max_health := 100.0
@export var target_min_health_percentage := 30.0
@export var target_max_health_percentage := 80.0

var _episode_time := 0.0
var _is_running := false
var _run_number := 0
var _initial_difficulty := 0
var _min_difficulty := 0
var _max_difficulty := 0
var _difficulty_changes := 0
var _last_difficulty_level := -1
var _difficulty_time_sum := 0.0
var _difficulty_tracking_time := 0.0
var _time_in_target_range := 0.0

@onready var difficulty_manager: DifficultyManager = $DifficultyManager
@onready var enemy_turret: EnemyTurret = $EnemyTurret
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var projectiles: Node2D = $Projectiles
@onready var simulated_player: SimulatedPlayer = $SimulatedPlayer
@onready var rule_based_dda: RuleBasedDDA = get_node_or_null("RuleBasedDDA") as RuleBasedDDA
@onready var dda_ai_controller: DDAAIController = get_node_or_null("DDAAIController") as DDAAIController

func _ready() -> void:
	Engine.time_scale = simulation_speed

	difficulty_manager.difficulty_changed.connect(_on_difficulty_changed)
	simulated_player.died.connect(_on_simulated_player_died)

	_prepare_results_file()
	_start_run()


func _process(delta: float) -> void:
	if not _is_running:
		return

	_episode_time += delta
	_update_difficulty_tracking(delta)
	_update_target_range_time(delta)

	if _episode_time >= episode_duration:
		_finish_run(false)


func _start_run() -> void:
	if _run_number >= max_runs:
		enemy_turret.set_active(false)
		Engine.time_scale = 1.0
		print("Experiment complete. Results saved to: ", ProjectSettings.globalize_path(results_file_path))
		return

	_run_number += 1
	_episode_time = 0.0
	_is_running = true

	_clear_projectiles()

	simulated_player.reset_player(player_spawn.global_position, _run_number, max_runs)

	_reset_difficulty_tracking(static_difficulty_level)
	difficulty_manager.set_difficulty_level(static_difficulty_level)
	
	if dda_ai_controller != null:
		dda_ai_controller.reset()
	
	if _is_rule_based_system() and rule_based_dda != null:
		rule_based_dda.reset()
		rule_based_dda.set_active(true)
	elif rule_based_dda != null:
		rule_based_dda.set_active(false)

	enemy_turret.set_active(true)

	print("Starting run ", _run_number)


func _finish_run(player_died: bool) -> void:
	if not _is_running:
		return

	_is_running = false
	enemy_turret.set_active(false)
	
	if rule_based_dda != null:
		rule_based_dda.set_active(false)

	_append_result(player_died)

	await get_tree().create_timer(reset_delay).timeout

	_start_run()


func _prepare_results_file() -> void:
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
	var file := FileAccess.open(results_file_path, FileAccess.READ_WRITE)

	if file == null:
		push_error("Could not open results file: " + results_file_path)
		return

	var clamped_survival_time := minf(simulated_player.survival_time, episode_duration)
	var clamped_target_time := minf(_time_in_target_range, clamped_survival_time)
	var target_range_percentage := 0.0

	if clamped_survival_time > 0.0:
		target_range_percentage = (clamped_target_time / clamped_survival_time) * 100.0

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


func _reset_difficulty_tracking(starting_difficulty: int) -> void:
	_initial_difficulty = starting_difficulty
	_min_difficulty = starting_difficulty
	_max_difficulty = starting_difficulty
	_difficulty_changes = 0
	_last_difficulty_level = starting_difficulty
	_difficulty_time_sum = 0.0
	_difficulty_tracking_time = 0.0
	_time_in_target_range = 0.0


func _update_difficulty_tracking(delta: float) -> void:
	_difficulty_time_sum += float(difficulty_manager.difficulty_level) * delta
	_difficulty_tracking_time += delta


func _update_target_range_time(delta: float) -> void:
	var health_percentage := 0.0

	if player_max_health > 0.0:
		health_percentage = (simulated_player.get_health_remaining() / player_max_health) * 100.0

	if health_percentage >= target_min_health_percentage and health_percentage <= target_max_health_percentage:
		_time_in_target_range += delta


func _get_average_difficulty() -> float:
	if _difficulty_tracking_time <= 0.0:
		return float(_initial_difficulty)

	return _difficulty_time_sum / _difficulty_tracking_time


func _clear_projectiles() -> void:
	for child in projectiles.get_children():
		child.queue_free()


func _on_difficulty_changed(difficulty_level: int) -> void:
	enemy_turret.apply_difficulty(difficulty_level)

	_min_difficulty = mini(_min_difficulty, difficulty_level)
	_max_difficulty = maxi(_max_difficulty, difficulty_level)

	if difficulty_level != _last_difficulty_level:
		_difficulty_changes += 1
		_last_difficulty_level = difficulty_level


func _on_simulated_player_died() -> void:
	_finish_run(true)


func _is_rule_based_system() -> bool:
	return system_name.to_lower() == "rule_based"

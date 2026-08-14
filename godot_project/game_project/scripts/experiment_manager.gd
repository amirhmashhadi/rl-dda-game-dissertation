class_name ExperimentManager
extends Node2D

const RESULTS_FILE_PATH := "res://data/raw/static_baseline_results.csv"
const STATIC_DIFFICULTY_LEVEL := 5
const SYSTEM_NAME := "static"

@export var episode_duration := 60.0
@export var max_runs := 10
@export var reset_delay := 1.0
@export var simulation_speed := 5.0

var _episode_time := 0.0
var _is_running := false
var _run_number := 0

@onready var difficulty_manager: DifficultyManager = $DifficultyManager
@onready var enemy_turret: EnemyTurret = $EnemyTurret
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var projectiles: Node2D = $Projectiles
@onready var simulated_player: SimulatedPlayer = $SimulatedPlayer


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

	if _episode_time >= episode_duration:
		_finish_run(false)


func _start_run() -> void:
	if _run_number >= max_runs:
		enemy_turret.set_active(false)
		Engine.time_scale = 1.0
		print("Experiment complete. Results saved to: ", ProjectSettings.globalize_path(RESULTS_FILE_PATH))
		return

	_run_number += 1
	_episode_time = 0.0
	_is_running = true

	_clear_projectiles()

	simulated_player.reset_player(player_spawn.global_position)
	difficulty_manager.set_difficulty_level(STATIC_DIFFICULTY_LEVEL)
	enemy_turret.set_active(true)

	print("Starting run ", _run_number)


func _finish_run(player_died: bool) -> void:
	if not _is_running:
		return

	_is_running = false
	enemy_turret.set_active(false)

	_append_result(player_died)

	await get_tree().create_timer(reset_delay).timeout

	_start_run()


func _prepare_results_file() -> void:
	var file := FileAccess.open(RESULTS_FILE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not create results file.")
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
		"final_difficulty"
	]))


func _append_result(player_died: bool) -> void:
	var file := FileAccess.open(RESULTS_FILE_PATH, FileAccess.READ_WRITE)

	if file == null:
		push_error("Could not open results file.")
		return

	file.seek_end()
	file.store_csv_line(PackedStringArray([
		simulated_player.profile_name,
		SYSTEM_NAME,
		str(_run_number),
		str(player_died),
		str(snappedf(simulated_player.survival_time, 0.01)),
		str(simulated_player.score),
		str(snappedf(simulated_player.get_health_remaining(), 0.01)),
		str(simulated_player.hits_taken),
		str(simulated_player.deaths),
		str(difficulty_manager.difficulty_level)
	]))


func _clear_projectiles() -> void:
	for child in projectiles.get_children():
		child.queue_free()


func _on_difficulty_changed(difficulty_level: int) -> void:
	enemy_turret.apply_difficulty(difficulty_level)


func _on_simulated_player_died() -> void:
	_finish_run(true)

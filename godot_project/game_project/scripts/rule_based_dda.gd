class_name RuleBasedDDA
extends Node

# References to the difficulty system and simulated player.
@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"

@export_group("Adjustment Settings")

# Controls how often the rule-based system checks player performance.
@export var adjustment_interval := 5.0

# Health values used to decide whether difficulty should change.
@export var player_max_health := 100.0
@export var low_health_threshold := 30.0
@export var high_health_threshold := 80.0

# Tracks whether the controller is active and when the next check should happen.
var _is_active := false
var _timer := 0.0

@onready var difficulty_manager: DifficultyManager = get_node(
	difficulty_manager_path
) as DifficultyManager

@onready var simulated_player: SimulatedPlayer = get_node(
	simulated_player_path
) as SimulatedPlayer


func _ready() -> void:
	# Keep the controller disabled until an experiment activates it.
	set_process(false)


func reset() -> void:
	# Reset the adjustment timer between episodes.
	_timer = 0.0


func set_active(value: bool) -> void:
	# Enable or disable rule-based difficulty adjustment.
	_is_active = value
	_timer = 0.0
	set_process(value)


func _process(delta: float) -> void:
	if not _is_active:
		return

	# Stop processing if there is no valid living player.
	if simulated_player == null or simulated_player.is_dead():
		return

	# Wait until the next adjustment interval.
	_timer += delta

	if _timer < adjustment_interval:
		return

	_timer = 0.0
	_adjust_difficulty()


func _adjust_difficulty() -> void:
	# Calculate the player's current health percentage.
	var health_percentage := 0.0

	if player_max_health > 0.0:
		health_percentage = (
			simulated_player.get_health_remaining()
			/ player_max_health
		) * 100.0

	var survival_time := simulated_player.survival_time
	var hits_taken := simulated_player.hits_taken

	# Reduce difficulty if the player's health is very low.
	if health_percentage < low_health_threshold:
		difficulty_manager.decrease_difficulty()
		return

	# Reduce difficulty if the player has taken many hits.
	if hits_taken >= 8:
		difficulty_manager.decrease_difficulty()
		return

	# Avoid increasing difficulty too early in the episode.
	if survival_time < 20.0:
		difficulty_manager.maintain_difficulty()
		return

	# Increase difficulty if the player is healthy and has taken few hits.
	if health_percentage > high_health_threshold and hits_taken <= 2:
		difficulty_manager.increase_difficulty()
		return

	# Keep the current difficulty if no rule is triggered.
	difficulty_manager.maintain_difficulty()

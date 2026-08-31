class_name DDAAIController
extends AIController2D

@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"

@export_group("Decision Settings")
@export var decision_interval := 5.0
@export var minimum_survival_time_before_increase := 25.0
@export var hits_needed_before_decrease := 2
@export var hits_allowed_before_increase := 0
@export var minimum_allowed_difficulty := 2
@export var maximum_allowed_difficulty := 7

@export_group("Target Range")
@export var player_max_health := 100.0
@export var low_health_threshold := 30.0
@export var high_health_threshold := 80.0

@export_group("Reward Settings")
@export var target_range_reward := 1.0
@export var low_health_penalty := -1.5
@export var high_health_penalty := -0.15
@export var death_penalty := -3.0
@export var hit_penalty := 0.10
@export var difficulty_change_penalty := 0.01
@export var invalid_action_penalty := 0.1
@export var too_easy_penalty := 1.0
@export var too_hard_penalty := 1.0

var _last_reward_hits_taken := 0
var _hits_at_last_decision := 0
var _last_action := 1
var _last_decision_time := 0.0
var _episode_reward := 0.0
var _pending_change_penalty := false
var _pending_invalid_action_penalty := false

@onready var difficulty_manager: DifficultyManager = get_node(difficulty_manager_path) as DifficultyManager
@onready var simulated_player: SimulatedPlayer = get_node(simulated_player_path) as SimulatedPlayer


func reset() -> void:
	_last_reward_hits_taken = 0
	_hits_at_last_decision = 0
	_last_action = 1
	_last_decision_time = 0.0
	_episode_reward = 0.0
	_pending_change_penalty = false
	_pending_invalid_action_penalty = false

	if simulated_player != null:
		_last_reward_hits_taken = simulated_player.hits_taken
		_hits_at_last_decision = simulated_player.hits_taken


func get_obs() -> Dictionary:
	var health_percentage := _get_health_percentage()
	var hits_since_decision := _get_hits_since_last_decision()
	var difficulty_normalised := float(difficulty_manager.difficulty_level) / 10.0
	var survival_normalised := clampf(simulated_player.survival_time / 60.0, 0.0, 1.0)

	return {
		"obs": [
			health_percentage / 100.0,
			clampf(float(hits_since_decision) / 5.0, 0.0, 1.0),
			difficulty_normalised,
			survival_normalised,
		]
	}


func get_reward() -> float:
	var reward := 0.0
	var health_percentage := _get_health_percentage()
	var hits_since_reward := _get_hits_since_last_reward()
	var hits_since_decision := _get_hits_since_last_decision()

	if simulated_player.is_dead():
		reward += death_penalty
	elif health_percentage < low_health_threshold:
		reward += low_health_penalty
	elif health_percentage > high_health_threshold:
		reward += high_health_penalty
	else:
		reward += target_range_reward

	reward -= float(hits_since_reward) * hit_penalty

	if _is_too_easy(health_percentage, hits_since_decision):
		reward -= too_easy_penalty

	if _is_too_hard(health_percentage, hits_since_decision):
		reward -= too_hard_penalty

	if _pending_change_penalty:
		reward -= difficulty_change_penalty
		_pending_change_penalty = false

	if _pending_invalid_action_penalty:
		reward -= invalid_action_penalty
		_pending_invalid_action_penalty = false

	_episode_reward += reward
	_last_reward_hits_taken = simulated_player.hits_taken

	return reward


func get_action_space() -> Dictionary:
	return {
		"dda_action": {
			"size": 3,
			"action_type": "discrete"
		}
	}


func set_action(action) -> void:
	if simulated_player == null or simulated_player.is_dead():
		return

	var current_time := simulated_player.survival_time

	if current_time - _last_decision_time < decision_interval:
		return

	_last_decision_time = current_time

	var dda_action := int(action["dda_action"])
	var health_percentage := _get_health_percentage()
	var hits_since_decision := _get_hits_since_last_decision()
	var difficulty_before_action := difficulty_manager.difficulty_level

	if _should_block_action(
		dda_action,
		health_percentage,
		hits_since_decision,
		current_time
	):
		_last_action = 1
		_pending_invalid_action_penalty = true
		difficulty_manager.maintain_difficulty()
		_hits_at_last_decision = simulated_player.hits_taken
		return

	match dda_action:
		0:
			difficulty_manager.decrease_difficulty()
		1:
			difficulty_manager.maintain_difficulty()
		2:
			difficulty_manager.increase_difficulty()

	_last_action = dda_action

	var difficulty_after_action := difficulty_manager.difficulty_level
	_pending_change_penalty = difficulty_after_action != difficulty_before_action
	_hits_at_last_decision = simulated_player.hits_taken


func get_episode_reward() -> float:
	return _episode_reward


func _should_block_action(
	dda_action: int,
	health_percentage: float,
	hits_since_decision: int,
	current_time: float
) -> bool:
	var current_difficulty := difficulty_manager.difficulty_level

	if dda_action == 0:
		if current_difficulty <= minimum_allowed_difficulty:
			return true

		if health_percentage > low_health_threshold and hits_since_decision < hits_needed_before_decrease:
			return true

	if dda_action == 2:
		if current_difficulty >= maximum_allowed_difficulty:
			return true

		if current_time < minimum_survival_time_before_increase:
			return true

		if health_percentage < high_health_threshold:
			return true

		if hits_since_decision > hits_allowed_before_increase:
			return true

	return false


func _is_too_easy(health_percentage: float, hits_since_decision: int) -> bool:
	if difficulty_manager.difficulty_level > minimum_allowed_difficulty:
		return false

	if health_percentage < 70.0:
		return false

	if hits_since_decision > hits_allowed_before_increase:
		return false

	return true


func _is_too_hard(health_percentage: float, hits_since_decision: int) -> bool:
	if difficulty_manager.difficulty_level < maximum_allowed_difficulty:
		return false

	if health_percentage > 40.0 and hits_since_decision < 2:
		return false

	return true


func _get_health_percentage() -> float:
	if player_max_health <= 0.0:
		return 0.0

	return (simulated_player.get_health_remaining() / player_max_health) * 100.0


func _get_hits_since_last_reward() -> int:
	return simulated_player.hits_taken - _last_reward_hits_taken


func _get_hits_since_last_decision() -> int:
	return simulated_player.hits_taken - _hits_at_last_decision

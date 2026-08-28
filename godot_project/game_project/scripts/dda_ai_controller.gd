class_name DDAAIController
extends AIController2D

@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"

@export_group("Target Range")
@export var player_max_health := 100.0
@export var low_health_threshold := 30.0
@export var high_health_threshold := 80.0

@export_group("Reward Settings")
@export var target_range_reward := 1.0
@export var low_health_penalty := -1.0
@export var high_health_penalty := -0.25
@export var death_penalty := -2.0
@export var hit_penalty := 0.15
@export var difficulty_change_penalty := 0.05

var _last_hits_taken := 0
var _last_action := 1
var _episode_reward := 0.0

@onready var difficulty_manager: DifficultyManager = get_node(difficulty_manager_path) as DifficultyManager
@onready var simulated_player: SimulatedPlayer = get_node(simulated_player_path) as SimulatedPlayer


func reset() -> void:
	_last_hits_taken = 0
	_last_action = 1
	_episode_reward = 0.0

	if simulated_player != null:
		_last_hits_taken = simulated_player.hits_taken


func get_obs() -> Dictionary:
	var health_percentage := _get_health_percentage()
	var recent_hits := _get_recent_hits()
	var difficulty_normalised := float(difficulty_manager.difficulty_level) / 10.0
	var survival_normalised := clampf(simulated_player.survival_time / 60.0, 0.0, 1.0)

	return {
		"obs": [
			health_percentage / 100.0,
			float(recent_hits) / 5.0,
			difficulty_normalised,
			survival_normalised,
		]
	}


func get_reward() -> float:
	var reward := 0.0
	var health_percentage := _get_health_percentage()
	var recent_hits := _get_recent_hits()

	if simulated_player.is_dead():
		reward += death_penalty
	elif health_percentage < low_health_threshold:
		reward += low_health_penalty
	elif health_percentage > high_health_threshold:
		reward += high_health_penalty
	else:
		reward += target_range_reward

	reward -= float(recent_hits) * hit_penalty

	if _last_action != 1:
		reward -= difficulty_change_penalty

	_episode_reward += reward
	_last_hits_taken = simulated_player.hits_taken

	return reward


func get_action_space() -> Dictionary:
	return {
		"dda_action": {
			"size": 3,
			"action_type": "discrete"
		}
	}


func set_action(action) -> void:
	var dda_action := int(action["dda_action"])

	_last_action = dda_action

	match dda_action:
		0:
			difficulty_manager.decrease_difficulty()
		1:
			difficulty_manager.maintain_difficulty()
		2:
			difficulty_manager.increase_difficulty()


func get_episode_reward() -> float:
	return _episode_reward


func _get_health_percentage() -> float:
	if player_max_health <= 0.0:
		return 0.0

	return (simulated_player.get_health_remaining() / player_max_health) * 100.0


func _get_recent_hits() -> int:
	return simulated_player.hits_taken - _last_hits_taken

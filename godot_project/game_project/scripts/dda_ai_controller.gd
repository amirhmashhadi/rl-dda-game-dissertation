class_name DDAAIController
extends AIController2D
 
@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"
 
@export_group("DDA Timing")
@export var action_cooldown := 5.0
 
@export_group("Target Flow Zone Settings")
@export var player_max_health := 100.0
@export var target_health_percentage := 60.0
@export var health_tolerance_range := 30.0
 
@export_group("Reward Tuning")
@export var flow_reward_scale := 1.2
@export var death_penalty := 10.0  # CHANGED: was 5.0 - too weak relative to accumulated per-step reward
@export var hit_penalty := 0.10
@export var proactive_help_bonus := 0.5
@export var challenge_bonus := 0.5
@export var direction_reversal_penalty := 0.1
@export var underchallenge_penalty := 0.4
@export var overchallenge_penalty := 0.4
@export var maintain_when_unbalanced_penalty := 0.35
@export var unnecessary_change_penalty := 0.05
@export var balanced_maintain_bonus := 0.05  # CHANGED: was hardcoded 0.15 in _get_action_quality_bonus
 
@export_group("Emergency Reaction")
@export var emergency_health_trend_threshold := -0.3  # CHANGED: new - lets agent act mid-cooldown if health is crashing
@export var emergency_hits_threshold := 3               # CHANGED: new - lets agent act mid-cooldown after a hit streak
 
@export_group("Difficulty Scale")
@export var minimum_allowed_difficulty := 0
@export var maximum_allowed_difficulty := 10
 
var _last_reward_hits_taken := 0
var _hits_at_last_action := 0
var _episode_reward := 0.0
var _action_bonus := 0.0
 
var _time_since_last_change := 0.0
var _last_action := 1
 
var _previous_health := 100.0
var _health_trend := 0.0
 
@onready var difficulty_manager: DifficultyManager = get_node(difficulty_manager_path) as DifficultyManager
@onready var simulated_player: SimulatedPlayer = get_node(simulated_player_path) as SimulatedPlayer
 
 
func _physics_process(delta: float) -> void:
	_time_since_last_change += delta
 
 
func reset() -> void:
	_last_reward_hits_taken = 0
	_hits_at_last_action = 0
	_episode_reward = 0.0
	_action_bonus = 0.0
 
	_time_since_last_change = action_cooldown
	_last_action = 1
 
	_previous_health = player_max_health
	_health_trend = 0.0
 
	if simulated_player != null:
		_last_reward_hits_taken = simulated_player.hits_taken
		_hits_at_last_action = simulated_player.hits_taken
		_previous_health = simulated_player.get_health_remaining()
 
 
func get_obs() -> Dictionary:
	var current_health := _get_health_percentage()
 
	_health_trend = clampf((current_health - _previous_health) / 20.0, -1.0, 1.0)
	_previous_health = current_health
 
	var hits_since_action := simulated_player.hits_taken - _hits_at_last_action
 
	var health_norm := clampf(current_health / 100.0, 0.0, 1.0)
	var health_trend_norm := _health_trend
	var hits_norm := clampf(float(hits_since_action) / 5.0, 0.0, 1.0)
	var difficulty_norm := clampf(float(difficulty_manager.difficulty_level) / 10.0, 0.0, 1.0)
	var survival_norm := clampf(simulated_player.survival_time / 60.0, 0.0, 1.0)
	var cooldown_norm := clampf(_time_since_last_change / action_cooldown, 0.0, 1.0)
 
	return {
		"obs": [
			health_norm,
			health_trend_norm,
			hits_norm,
			difficulty_norm,
			survival_norm,
			cooldown_norm
		]
	}
 
 
func get_reward() -> float:
	var reward := 0.0
	var health_percentage := _get_health_percentage()
	var hits_since_reward := _get_hits_since_last_reward()
	var current_difficulty := difficulty_manager.difficulty_level
 
	if simulated_player.is_dead():
		reward -= death_penalty
	else:
		var error := (health_percentage - target_health_percentage) / health_tolerance_range
		var flow_score := 1.0 - pow(error, 2.0)
		reward += flow_score * flow_reward_scale
 
		var player_too_safe := health_percentage > 80.0 and simulated_player.survival_time > 10.0
		var player_struggling := health_percentage < 45.0
 
		if player_too_safe and current_difficulty <= 5:
			reward -= underchallenge_penalty
 
		if player_struggling and current_difficulty >= 5:
			reward -= overchallenge_penalty
 
		if current_difficulty > 5 and health_percentage >= 50.0:
			var high_difficulty_bonus := (float(current_difficulty - 5) / 5.0) * 0.15
			reward += high_difficulty_bonus
 
	reward -= float(hits_since_reward) * hit_penalty
 
	reward += _action_bonus
	_action_bonus = 0.0
 
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
 
	var dda_action := int(action["dda_action"])
	var current_difficulty := difficulty_manager.difficulty_level
	var current_health := _get_health_percentage()
	var hits_since_action := simulated_player.hits_taken - _hits_at_last_action
 
	# CHANGED: emergency override - let the agent react before cooldown expires
	# if health is crashing fast or the player just ate a hit streak, instead of
	# being force-locked to "maintain" for the full 5s window.
	var in_emergency := _health_trend < emergency_health_trend_threshold or hits_since_action >= emergency_hits_threshold
 
	if _time_since_last_change < action_cooldown and dda_action != 1 and not in_emergency:
		dda_action = 1
 
	if (_last_action == 0 and dda_action == 2) or (_last_action == 2 and dda_action == 0):
		_action_bonus -= direction_reversal_penalty
 
	_action_bonus += _get_action_quality_bonus(
		dda_action,
		current_health,
		hits_since_action
	)
 
	match dda_action:
		0:
			if current_difficulty > minimum_allowed_difficulty:
				difficulty_manager.decrease_difficulty()
				_time_since_last_change = 0.0
 
		1:
			difficulty_manager.maintain_difficulty()
 
		2:
			if current_difficulty < maximum_allowed_difficulty:
				difficulty_manager.increase_difficulty()
				_time_since_last_change = 0.0
 
		_:
			push_warning("Unknown RL action received: " + str(dda_action))
			difficulty_manager.maintain_difficulty()
 
	_last_action = dda_action
	_hits_at_last_action = simulated_player.hits_taken
 
 
func get_episode_reward() -> float:
	return _episode_reward
 
 
func _get_action_quality_bonus(
	dda_action: int,
	health_percentage: float,
	hits_since_action: int
) -> float:
	var player_too_safe := health_percentage > 80.0 and hits_since_action == 0
	var player_struggling := health_percentage < 45.0 or hits_since_action >= 2 or _health_trend < -0.15
	var player_balanced := not player_too_safe and not player_struggling
 
	if player_too_safe:
		if dda_action == 2:
			return challenge_bonus
 
		if dda_action == 1:
			return -maintain_when_unbalanced_penalty
 
		return -challenge_bonus
 
	if player_struggling:
		if dda_action == 0:
			return proactive_help_bonus
 
		if dda_action == 1:
			return -maintain_when_unbalanced_penalty
 
		return -proactive_help_bonus
 
	if player_balanced:
		if dda_action == 1:
			return balanced_maintain_bonus  # CHANGED: was hardcoded 0.15
 
		return -unnecessary_change_penalty
 
	return 0.0
 
 
func _get_health_percentage() -> float:
	if player_max_health <= 0.0:
		return 0.0
 
	return (simulated_player.get_health_remaining() / player_max_health) * 100.0
 
 
func _get_hits_since_last_reward() -> int:
	return simulated_player.hits_taken - _last_reward_hits_taken

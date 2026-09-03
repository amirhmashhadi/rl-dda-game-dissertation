class_name DDAAIController
extends AIController2D

# References to the main difficulty system and simulated player.
@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"

@export_group("DDA Timing")

# Minimum time between normal difficulty changes.
@export var action_cooldown := 5.0

@export_group("Target Flow Zone Settings")

# Health values used to define the desired gameplay balance range.
@export var player_max_health := 100.0
@export var target_health_percentage := 60.0
@export var health_tolerance_range := 30.0

@export_group("Reward Tuning")

# Reward values used to shape the PPO agent's behaviour.
@export var flow_reward_scale := 1.2
@export var death_penalty := 10.0
@export var hit_penalty := 0.10
@export var proactive_help_bonus := 0.5
@export var challenge_bonus := 0.5
@export var direction_reversal_penalty := 0.1
@export var underchallenge_penalty := 0.4
@export var overchallenge_penalty := 0.4
@export var maintain_when_unbalanced_penalty := 0.35
@export var unnecessary_change_penalty := 0.05
@export var balanced_maintain_bonus := 0.05

@export_group("Emergency Reaction")

# Allows the agent to bypass the cooldown if the player is struggling badly.
@export var emergency_health_trend_threshold := -0.3
@export var emergency_hits_threshold := 3

@export_group("Difficulty Scale")

# Limits the difficulty values the RL agent is allowed to select.
@export var minimum_allowed_difficulty := 0
@export var maximum_allowed_difficulty := 10

# Values used to track rewards and player damage between decisions.
var _last_reward_hits_taken := 0
var _hits_at_last_action := 0
var _episode_reward := 0.0
var _action_bonus := 0.0

# Tracks when difficulty can next be changed and the previous RL action.
var _time_since_last_change := 0.0
var _last_action := 1

# Tracks changes in player health between observations.
var _previous_health := 100.0
var _health_trend := 0.0

@onready var difficulty_manager: DifficultyManager = get_node(
	difficulty_manager_path
) as DifficultyManager

@onready var simulated_player: SimulatedPlayer = get_node(
	simulated_player_path
) as SimulatedPlayer


func _physics_process(delta: float) -> void:
	# Track how long it has been since the last difficulty change.
	_time_since_last_change += delta


func reset() -> void:
	# Reset reward and hit tracking at the start of each episode.
	_last_reward_hits_taken = 0
	_hits_at_last_action = 0
	_episode_reward = 0.0
	_action_bonus = 0.0

	# Allow an immediate action at the beginning of the episode.
	_time_since_last_change = action_cooldown
	_last_action = 1

	_previous_health = player_max_health
	_health_trend = 0.0

	# Synchronise tracking values with the newly reset player.
	if simulated_player != null:
		_last_reward_hits_taken = simulated_player.hits_taken
		_hits_at_last_action = simulated_player.hits_taken
		_previous_health = simulated_player.get_health_remaining()


func get_obs() -> Dictionary:
	# Build the six normalised values given to the PPO agent.
	var current_health := _get_health_percentage()

	# Measure how quickly the player's health has changed.
	_health_trend = clampf(
		(current_health - _previous_health) / 20.0,
		-1.0,
		1.0
	)
	_previous_health = current_health

	var hits_since_action := simulated_player.hits_taken - _hits_at_last_action

	# Normalise gameplay values before sending them to the RL model.
	var health_norm := clampf(current_health / 100.0, 0.0, 1.0)
	var health_trend_norm := _health_trend
	var hits_norm := clampf(float(hits_since_action) / 5.0, 0.0, 1.0)
	var difficulty_norm := clampf(
		float(difficulty_manager.difficulty_level) / 10.0,
		0.0,
		1.0
	)
	var survival_norm := clampf(
		simulated_player.survival_time / 60.0,
		0.0,
		1.0
	)
	var cooldown_norm := clampf(
		_time_since_last_change / action_cooldown,
		0.0,
		1.0
	)

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
	# Calculate the reward for the player's current gameplay state.
	var reward := 0.0
	var health_percentage := _get_health_percentage()
	var hits_since_reward := _get_hits_since_last_reward()
	var current_difficulty := difficulty_manager.difficulty_level

	# Death receives a strong penalty.
	if simulated_player.is_dead():
		reward -= death_penalty
	else:
		# Reward health values that remain near the target percentage.
		var error := (
			health_percentage - target_health_percentage
		) / health_tolerance_range

		var flow_score := 1.0 - pow(error, 2.0)
		reward += flow_score * flow_reward_scale

		var player_too_safe := (
			health_percentage > 80.0
			and simulated_player.survival_time > 10.0
		)

		var player_struggling := health_percentage < 45.0

		# Penalise low difficulty when the player is clearly under-challenged.
		if player_too_safe and current_difficulty <= 5:
			reward -= underchallenge_penalty

		# Penalise high difficulty when the player is struggling.
		if player_struggling and current_difficulty >= 5:
			reward -= overchallenge_penalty

		# Give a small reward for maintaining survivable higher difficulty.
		if current_difficulty > 5 and health_percentage >= 50.0:
			var high_difficulty_bonus := (
				float(current_difficulty - 5) / 5.0
			) * 0.15

			reward += high_difficulty_bonus

	# Penalise recent hits taken by the player.
	reward -= float(hits_since_reward) * hit_penalty

	# Apply any reward or penalty produced by the previous action.
	reward += _action_bonus
	_action_bonus = 0.0

	# Track total reward for the current episode.
	_episode_reward += reward
	_last_reward_hits_taken = simulated_player.hits_taken

	return reward


func get_action_space() -> Dictionary:
	# PPO can decrease, maintain, or increase difficulty.
	return {
		"dda_action": {
			"size": 3,
			"action_type": "discrete"
		}
	}


func set_action(action) -> void:
	# Ignore actions if there is no active player.
	if simulated_player == null or simulated_player.is_dead():
		return

	var dda_action := int(action["dda_action"])
	var current_difficulty := difficulty_manager.difficulty_level
	var current_health := _get_health_percentage()
	var hits_since_action := simulated_player.hits_taken - _hits_at_last_action

	# Allow urgent difficulty changes even if the normal cooldown is active.
	var in_emergency := (
		_health_trend < emergency_health_trend_threshold
		or hits_since_action >= emergency_hits_threshold
	)

	# Force maintain if the agent tries to change difficulty too soon.
	if (
		_time_since_last_change < action_cooldown
		and dda_action != 1
		and not in_emergency
	):
		dda_action = 1

	# Discourage rapidly reversing between increasing and decreasing difficulty.
	if (
		(_last_action == 0 and dda_action == 2)
		or (_last_action == 2 and dda_action == 0)
	):
		_action_bonus -= direction_reversal_penalty

	# Reward or penalise the action based on the player's condition.
	_action_bonus += _get_action_quality_bonus(
		dda_action,
		current_health,
		hits_since_action
	)

	# Apply the chosen difficulty action.
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

	# Store information used by the next action decision.
	_last_action = dda_action
	_hits_at_last_action = simulated_player.hits_taken


func get_episode_reward() -> float:
	# Return the total reward accumulated during the episode.
	return _episode_reward


func _get_action_quality_bonus(
	dda_action: int,
	health_percentage: float,
	hits_since_action: int
) -> float:
	# Classify the player's current condition.
	var player_too_safe := (
		health_percentage > 80.0
		and hits_since_action == 0
	)

	var player_struggling := (
		health_percentage < 45.0
		or hits_since_action >= 2
		or _health_trend < -0.15
	)

	var player_balanced := not player_too_safe and not player_struggling

	# Encourage increasing difficulty when the player is too safe.
	if player_too_safe:
		if dda_action == 2:
			return challenge_bonus

		if dda_action == 1:
			return -maintain_when_unbalanced_penalty

		return -challenge_bonus

	# Encourage decreasing difficulty when the player is struggling.
	if player_struggling:
		if dda_action == 0:
			return proactive_help_bonus

		if dda_action == 1:
			return -maintain_when_unbalanced_penalty

		return -proactive_help_bonus

	# Prefer maintaining difficulty while the player is balanced.
	if player_balanced:
		if dda_action == 1:
			return balanced_maintain_bonus

		return -unnecessary_change_penalty

	return 0.0


func _get_health_percentage() -> float:
	# Convert the player's remaining health into a percentage.
	if player_max_health <= 0.0:
		return 0.0

	return (
		simulated_player.get_health_remaining()
		/ player_max_health
	) * 100.0


func _get_hits_since_last_reward() -> int:
	# Count new hits received since the previous reward calculation.
	return simulated_player.hits_taken - _last_reward_hits_taken

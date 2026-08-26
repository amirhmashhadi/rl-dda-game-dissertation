class_name RuleBasedDDA
extends Node

@export var difficulty_manager_path: NodePath = "../DifficultyManager"
@export var simulated_player_path: NodePath = "../SimulatedPlayer"

@export_group("Adjustment Settings")
@export var adjustment_interval := 5.0
@export var player_max_health := 100.0
@export var low_health_threshold := 30.0
@export var high_health_threshold := 80.0

var _is_active := false
var _timer := 0.0

@onready var difficulty_manager: DifficultyManager = get_node(difficulty_manager_path) as DifficultyManager
@onready var simulated_player: SimulatedPlayer = get_node(simulated_player_path) as SimulatedPlayer


func _ready() -> void:
	set_process(false)


func reset() -> void:
	_timer = 0.0


func set_active(value: bool) -> void:
	_is_active = value
	_timer = 0.0
	set_process(value)


func _process(delta: float) -> void:
	if not _is_active:
		return

	if simulated_player == null or simulated_player.is_dead():
		return

	_timer += delta

	if _timer < adjustment_interval:
		return

	_timer = 0.0
	_adjust_difficulty()


func _adjust_difficulty() -> void:
	var health_percentage := 0.0

	if player_max_health > 0.0:
		health_percentage = (simulated_player.get_health_remaining() / player_max_health) * 100.0

	var survival_time := simulated_player.survival_time
	var hits_taken := simulated_player.hits_taken

	if health_percentage < low_health_threshold:
		difficulty_manager.decrease_difficulty()
		return

	if hits_taken >= 8:
		difficulty_manager.decrease_difficulty()
		return

	if survival_time < 20.0:
		difficulty_manager.maintain_difficulty()
		return

	if health_percentage > high_health_threshold and hits_taken <= 2:
		difficulty_manager.increase_difficulty()
		return

	difficulty_manager.maintain_difficulty()

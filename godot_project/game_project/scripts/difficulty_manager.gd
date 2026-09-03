class_name DifficultyManager
extends Node

# Emitted whenever the difficulty level is updated.
signal difficulty_changed(difficulty_level: int)

# Allowed difficulty range.
const MAX_DIFFICULTY_LEVEL := 10
const MIN_DIFFICULTY_LEVEL := 0

# Starting difficulty used when the scene loads.
@export_range(0, 10, 1) var initial_difficulty_level := 5

var difficulty_level := initial_difficulty_level


func _ready() -> void:
	# Apply the starting difficulty and notify connected systems.
	set_difficulty_level(initial_difficulty_level)


func set_difficulty_level(value: int) -> void:
	# Keep difficulty within the valid 0-10 range.
	difficulty_level = clampi(
		value,
		MIN_DIFFICULTY_LEVEL,
		MAX_DIFFICULTY_LEVEL
	)

	# Notify other systems so they can update their settings.
	difficulty_changed.emit(difficulty_level)


func increase_difficulty() -> void:
	# Increase difficulty by one level.
	set_difficulty_level(difficulty_level + 1)


func decrease_difficulty() -> void:
	# Decrease difficulty by one level.
	set_difficulty_level(difficulty_level - 1)


func maintain_difficulty() -> void:
	# Keep the current difficulty unchanged.
	set_difficulty_level(difficulty_level)

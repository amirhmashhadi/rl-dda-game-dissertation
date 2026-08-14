class_name DifficultyManager
extends Node

signal difficulty_changed(difficulty_level: int)

const MAX_DIFFICULTY_LEVEL := 10
const MIN_DIFFICULTY_LEVEL := 0

@export_range(0, 10, 1) var initial_difficulty_level := 5

var difficulty_level := initial_difficulty_level


func _ready() -> void:
	set_difficulty_level(initial_difficulty_level)


func set_difficulty_level(value: int) -> void:
	difficulty_level = clampi(value, MIN_DIFFICULTY_LEVEL, MAX_DIFFICULTY_LEVEL)
	difficulty_changed.emit(difficulty_level)


func increase_difficulty() -> void:
	set_difficulty_level(difficulty_level + 1)


func decrease_difficulty() -> void:
	set_difficulty_level(difficulty_level - 1)


func maintain_difficulty() -> void:
	set_difficulty_level(difficulty_level)

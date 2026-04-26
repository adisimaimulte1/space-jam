extends Node
class_name HealthComponent

signal health_changed(current: int, max_health: int)
signal died

@export var default_max_health: int = 3

var max_health: int = 3
var current_health: int = 3
var dead: bool = false


func _ready() -> void:
	setup(default_max_health)


func setup(new_max_health: int) -> void:
	max_health = max(1, new_max_health)
	current_health = max_health
	dead = false
	health_changed.emit(current_health, max_health)


func damage(amount: int = 1) -> void:
	if dead:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		dead = true
		died.emit()


func heal(amount: int = 1) -> void:
	if dead:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

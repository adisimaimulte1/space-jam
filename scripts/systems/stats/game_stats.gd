extends Node
class_name GameStats

signal score_changed(score: int)
signal player_lives_changed(lives: int, max_lives: int)
signal game_over

@export var player_max_lives: int = 3

var score: int = 0
var player_lives: int = 3


func _ready() -> void:
	player_lives = player_max_lives
	score_changed.emit(score)
	player_lives_changed.emit(player_lives, player_max_lives)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func enemy_killed(enemy_type: String) -> void:
	add_score(ScoreDatabase.get_enemy_kill_points(enemy_type))


func planet_released(planet_type: String) -> void:
	add_score(ScoreDatabase.get_planet_release_points(planet_type))


func planet_lost(planet_type: String) -> void:
	add_score(ScoreDatabase.get_planet_lost_points(planet_type))


func damage_player(amount: int = 1) -> void:
	player_lives -= amount
	player_lives = max(player_lives, 0)

	player_lives_changed.emit(player_lives, player_max_lives)

	if player_lives <= 0:
		game_over.emit()

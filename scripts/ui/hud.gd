extends Control
class_name HUD

@onready var lives_label: Label = $LivesLabel
@onready var score_label: Label = $ScoreLabel

var game_stats: GameStats = null


func setup(stats: GameStats) -> void:
	game_stats = stats

	game_stats.score_changed.connect(_on_score_changed)
	game_stats.player_lives_changed.connect(_on_player_lives_changed)

	_on_score_changed(game_stats.score)
	_on_player_lives_changed(game_stats.player_lives, game_stats.player_max_lives)


func _on_score_changed(score: int) -> void:
	score_label.text = "Score: %d" % score


func _on_player_lives_changed(lives: int, max_lives: int) -> void:
	lives_label.text = "Lives: %d/%d" % [lives, max_lives]

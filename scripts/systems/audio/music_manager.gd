extends Node

var player: AudioStreamPlayer


func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)


func play_music(stream: AudioStream, from_position: float = 0.0):
	if stream == null:
		return

	var should_restart := player.stream != stream

	if should_restart:
		player.stop()
		player.stream = stream

	player.stream_paused = false

	if should_restart:
		player.play(from_position)
		player.stream.loop = true
	elif not player.playing:
		player.play(from_position)
		player.stream.loop = true


func stop_music():
	player.stop()


func pause_music():
	player.stream_paused = true


func resume_music():
	player.stream_paused = false


func toggle_pause():
	player.stream_paused = not player.stream_paused


func is_playing() -> bool:
	return player.playing


func is_same_stream(stream: AudioStream) -> bool:
	return player.stream == stream


func get_playback_position() -> float:
	if player.playing:
		return player.get_playback_position()
	return 0.0

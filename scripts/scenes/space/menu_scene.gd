extends Node2D

@onready var planets_layer = $Background/Planets
@onready var nebula_layer = $Background/Nebula
@onready var stars_layer = $Background/Stars

@onready var press_start = $UI/PressStart
@onready var logo = $UI/Logo

@export var menu_music_stream: AudioStream

var camera_time := 0.0
var camera_radius_x := 35.0
var camera_radius_y := 20.0
var camera_speed := 0.1

var anim_time := 0.0

var zoom_points = [
	Vector2(0.22, 0.30),
	Vector2(0.45, 0.22),
	Vector2(0.68, 0.40),
	Vector2(0.33, 0.64),
	Vector2(0.75, 0.70),
]
var selected_zoom_point := Vector2(0.5, 0.5)

var menu_center := Vector2(960, 540)

# Shared parallax factors
const STARS_DEPTH := 0.35
const PLANETS_DEPTH := 0.55
const NEBULA_DEPTH := 0.95


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	randomize()
	selected_zoom_point = zoom_points[randi() % zoom_points.size()]

	if menu_music_stream:
		MusicManager.play_music(menu_music_stream)


func get_camera_offset() -> Vector2:
	var angle = camera_time * TAU * camera_speed
	return Vector2(
		cos(angle) * camera_radius_x,
		sin(angle) * camera_radius_y
	)


func start_transition():
	selected_zoom_point = zoom_points[randi() % zoom_points.size()]

	# save current screen state for TransitionScene
	TransitionState.menu_camera_time = camera_time
	TransitionState.menu_zoom_point = selected_zoom_point

	TransitionState.menu_stars_position = stars_layer.position
	TransitionState.menu_planets_position = planets_layer.position
	TransitionState.menu_nebula_position = nebula_layer.position

	TransitionState.menu_stars_scale = stars_layer.scale
	TransitionState.menu_planets_scale = planets_layer.scale
	TransitionState.menu_nebula_alpha = nebula_layer.modulate.a

	TransitionState.menu_logo_alpha = logo.modulate.a
	TransitionState.menu_text_alpha = press_start.modulate.a
	TransitionState.menu_logo_position = logo.position
	TransitionState.menu_text_position = press_start.position

	TransitionState.menu_stars_texture_path = "res://assets/video/images/backgrounds/main_screen/space_background_stars.png"
	TransitionState.menu_planets_texture_path = "res://assets/video/images/backgrounds/main_screen/space_background_planets.png"
	TransitionState.menu_nebula_texture_path = "res://assets/video/images/backgrounds/main_screen/space_background_nebula.png"

	# pick a random game background now so TransitionScene and GameScene use the same one
	var star_paths = [
		"res://assets/video/images/backgrounds/game_screen/default_stars_64/stars_1.png",
		"res://assets/video/images/backgrounds/game_screen/default_stars_64/stars_2.png",
		"res://assets/video/images/backgrounds/game_screen/default_stars_64/stars_3.png"
	]
	TransitionState.game_star_texture_path = star_paths[randi() % star_paths.size()]

	# stop menu music before handing off
	MusicManager.stop_music()

	# ask GameRoot to swap screens
	get_tree().current_scene.switch_scene(preload("res://scenes/space/TransitionScene.tscn"))


func _input(event):
	if event.is_action_pressed("start_game"):
		start_transition()

	if event.is_action_pressed("stop_game"):
		get_tree().quit()


func _process(delta):
	anim_time += delta
	camera_time += delta
	
	if delta > 0.025:
		print("MENU FRAME SPIKE:", delta)

	var offset = get_camera_offset()

	stars_layer.position = menu_center + offset * STARS_DEPTH
	planets_layer.position = menu_center + offset * PLANETS_DEPTH
	nebula_layer.position = menu_center + offset * NEBULA_DEPTH

	press_start.visible = int(Time.get_ticks_msec() / 450.0) % 2 == 0

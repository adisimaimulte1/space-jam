extends Node2D

@onready var main_stars = $MenuLayer/Stars
@onready var main_planets = $MenuLayer/Planets
@onready var main_nebula = $MenuLayer/Nebula

@onready var game_stars_grid = $GameLayer/StarsGrid

@onready var logo = $UI/Logo
@onready var press_start = $UI/PressStart

@onready var transition_sfx = $TransitionSFX

var camera_time := 0.0
var camera_radius_x := 35.0
var camera_radius_y := 20.0
var camera_speed := 0.1

var fade_time := 0.0
var fade_duration := 1.2

var zoom_time := 0.0
var zoom_duration := 2.1

var fading_done := false
var game_music_started := false

var screen_center := Vector2(960, 540)

const STARS_DEPTH := 0.35
const PLANETS_DEPTH := 0.55
const NEBULA_DEPTH := 0.95

const GRID_COLS := 8
const GRID_ROWS := 8
const TILE_SIZE := Vector2(240, 135)
const TOTAL_TILES := GRID_COLS * GRID_ROWS

const LOADED_PATCH_RADIUS := 1 # 1 => 3x3 patch

var main_stars_scale_start := Vector2.ONE
var main_stars_scale_end := Vector2.ONE

var main_planets_scale_start := Vector2.ONE
var main_planets_scale_end := Vector2.ONE

var game_layer_scale_start := Vector2(0.12, 0.12)
var game_layer_scale_end := Vector2.ONE

var shuffled_star_paths: Array[String] = []
var chosen_tile_center_local := Vector2.ZERO

@export var game_music_stream: AudioStream
@export var game_stars_folder := "res://assets/video/images/backgrounds/game_screen/default_stars_64/"


func _ready():
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	$MenuLayer.z_index = 1
	$GameLayer.z_index = 0
	$UI.z_index = 2

	camera_time = TransitionState.menu_camera_time

	main_stars.texture = load(TransitionState.menu_stars_texture_path)
	main_planets.texture = load(TransitionState.menu_planets_texture_path)
	main_nebula.texture = load(TransitionState.menu_nebula_texture_path)

	main_stars.position = TransitionState.menu_stars_position
	main_planets.position = TransitionState.menu_planets_position
	main_nebula.position = TransitionState.menu_nebula_position

	main_stars.scale = TransitionState.menu_stars_scale
	main_planets.scale = TransitionState.menu_planets_scale
	main_nebula.modulate.a = TransitionState.menu_nebula_alpha

	logo.position = TransitionState.menu_logo_position
	press_start.position = TransitionState.menu_text_position
	logo.modulate.a = TransitionState.menu_logo_alpha
	press_start.modulate.a = TransitionState.menu_text_alpha

	main_stars_scale_start = TransitionState.menu_stars_scale
	main_planets_scale_start = TransitionState.menu_planets_scale

	main_stars_scale_end = main_stars_scale_start * 10.8
	main_planets_scale_end = main_planets_scale_start * 8.4

	build_game_stars_grid()

	$GameLayer.position = screen_center
	$GameLayer.scale = game_layer_scale_start
	$GameLayer.modulate.a = 1.0
	game_stars_grid.modulate.a = 0.0
	transition_sfx.play()

func build_game_stars_grid():
	clear_game_stars_grid()
	load_star_paths_only()

	if shuffled_star_paths.size() < TOTAL_TILES:
		push_error("Not enough star textures found. Need %d, got %d." % [TOTAL_TILES, shuffled_star_paths.size()])
		return

	shuffled_star_paths.shuffle()

	TransitionState.selected_game_star_grid_paths.clear()
	TransitionState.selected_game_star_grid_paths.append_array(shuffled_star_paths)

	var full_size := Vector2(GRID_COLS, GRID_ROWS) * TILE_SIZE
	var top_left := -full_size * 0.5

	var chosen_cell := pick_biased_inner_cell()
	var chosen_col: int = chosen_cell.x
	var chosen_row: int = chosen_cell.y

	TransitionState.selected_game_star_tile_row = chosen_row
	TransitionState.selected_game_star_tile_col = chosen_col

	chosen_tile_center_local = top_left + Vector2(
		chosen_col * TILE_SIZE.x + TILE_SIZE.x * 0.5,
		chosen_row * TILE_SIZE.y + TILE_SIZE.y * 0.5
	)

	TransitionState.selected_game_star_tile_center_local = chosen_tile_center_local

	var chosen_index := chosen_row * GRID_COLS + chosen_col
	var chosen_path := shuffled_star_paths[chosen_index]

	TransitionState.selected_game_star_texture_path = chosen_path
	TransitionState.game_star_texture_path = chosen_path

	for row in range(chosen_row - LOADED_PATCH_RADIUS, chosen_row + LOADED_PATCH_RADIUS + 1):
		for col in range(chosen_col - LOADED_PATCH_RADIUS, chosen_col + LOADED_PATCH_RADIUS + 1):
			if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
				continue

			var tile_index := row * GRID_COLS + col
			var path := shuffled_star_paths[tile_index]
			var tex := load(path) as Texture2D
			if tex == null:
				continue

			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

			var tile_center := top_left + Vector2(
				col * TILE_SIZE.x + TILE_SIZE.x * 0.5,
				row * TILE_SIZE.y + TILE_SIZE.y * 0.5
			)

			sprite.position = tile_center
			game_stars_grid.add_child(sprite)

	game_stars_grid.position = -chosen_tile_center_local

func pick_biased_inner_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	var weights: Array[float] = []

	var grid_center := Vector2(
		(GRID_COLS - 1) * 0.5,
		(GRID_ROWS - 1) * 0.5
	)

	for row in range(1, GRID_ROWS - 1):
		for col in range(1, GRID_COLS - 1):
			var cell_pos := Vector2(col, row)
			var dist_from_center := cell_pos.distance_to(grid_center)

			# Bigger weight = more likely.
			# Base weight keeps all inner cells possible,
			# distance term pushes picks farther from the center.
			var weight := 1.0 + dist_from_center * 2.2

			candidates.append(Vector2i(col, row))
			weights.append(weight)

	return weighted_pick_cell(candidates, weights)


func weighted_pick_cell(candidates: Array[Vector2i], weights: Array[float]) -> Vector2i:
	var total_weight := 0.0
	for w in weights:
		total_weight += w

	var roll := randf() * total_weight
	var running := 0.0

	for i in range(candidates.size()):
		running += weights[i]
		if roll <= running:
			return candidates[i]

	return candidates[-1]

func clear_game_stars_grid():
	for child in game_stars_grid.get_children():
		child.queue_free()


func load_star_paths_only():
	shuffled_star_paths.clear()

	var dir := DirAccess.open(game_stars_folder)
	if dir == null:
		push_error("Could not open folder: " + game_stars_folder)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.begins_with("stars_") and file_name.ends_with(".png"):
				shuffled_star_paths.append(game_stars_folder.path_join(file_name))
		file_name = dir.get_next()

	dir.list_dir_end()


func ease_in_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func ease_out_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func get_camera_offset() -> Vector2:
	var angle = camera_time * TAU * camera_speed
	return Vector2(
		cos(angle) * camera_radius_x,
		sin(angle) * camera_radius_y
	)


func get_zoomed_centered_position(texture_size: Vector2, scale_value: Vector2, anchor: Vector2, offset: Vector2, depth: float) -> Vector2:
	var scaled_size = texture_size * scale_value
	var focus_shift = Vector2(
		(0.5 - anchor.x) * scaled_size.x,
		(0.5 - anchor.y) * scaled_size.y
	)
	return screen_center + focus_shift + offset * depth

func start_game_music():
	if game_music_started:
		return

	if game_music_stream:
		MusicManager.play_music(game_music_stream)

	game_music_started = true


func _input(event):
	if event.is_action_pressed("stop_game"):
		get_tree().quit()


func _process(delta):
	camera_time += delta
	var offset = get_camera_offset()
	
	if delta > 0.025:
		print("TRANSITION SPIKE:", delta)

	if not fading_done:
		fade_time += delta
		var fade_t = ease_out_cubic(fade_time / fade_duration)

		main_stars.position = screen_center + offset * STARS_DEPTH
		main_planets.position = screen_center + offset * PLANETS_DEPTH
		main_nebula.position = screen_center + offset * NEBULA_DEPTH

		logo.modulate.a = 1.0 - fade_t
		press_start.modulate.a = 1.0 - fade_t
		main_nebula.modulate.a = 1.0 - fade_t

		logo.position.y = TransitionState.menu_logo_position.y - 500.0 * fade_t
		press_start.position.y = TransitionState.menu_text_position.y + 120.0 * fade_t

		if fade_time >= fade_duration:
			fading_done = true
			$GameLayer.z_index = 1
			$MenuLayer.z_index = 0

		return

	zoom_time += delta
	var zoom_t = ease_in_out(zoom_time / zoom_duration)

	var anchor = Vector2(0.5, 0.5).lerp(TransitionState.menu_zoom_point, zoom_t)

	start_game_music()

	var main_stars_scale = main_stars_scale_start.lerp(main_stars_scale_end, zoom_t)
	var main_planets_scale = main_planets_scale_start.lerp(main_planets_scale_end, zoom_t)

	main_stars.scale = main_stars_scale
	main_planets.scale = main_planets_scale

	main_stars.position = get_zoomed_centered_position(
		main_stars.texture.get_size(),
		main_stars_scale,
		anchor,
		offset,
		STARS_DEPTH
	)

	main_planets.position = get_zoomed_centered_position(
		main_planets.texture.get_size(),
		main_planets_scale,
		anchor,
		offset,
		PLANETS_DEPTH
	)

	$GameLayer.scale = game_layer_scale_start.lerp(game_layer_scale_end, zoom_t) * 8.3
	$GameLayer.position = screen_center + offset * STARS_DEPTH

	var grid_alpha := ease_in_out(clampf((zoom_t - 0.18) / 0.82, 0.0, 1.0))
	game_stars_grid.modulate.a = grid_alpha
	game_stars_grid.position = -chosen_tile_center_local

	if zoom_time >= zoom_duration:
		TransitionState.game_camera_time = camera_time
		TransitionState.game_star_start_position = screen_center + offset * STARS_DEPTH
		get_tree().current_scene.switch_scene(preload("res://scenes/space/GameScene.tscn"))

extends Node2D

@onready var camera_2d: Camera2D = $Camera2D
@onready var star_chunks: Node2D = $StarChunks
@onready var planet_layer: Node2D = $PlanetLayer
@onready var jar_layer: Node2D = $JarLayer
@onready var enemy_layer: Node2D = $EnemyLayer
@onready var planet_manager = $PlanetManager
@onready var rocket = $Rocket
@onready var game_stats: GameStats = $GameStats
@onready var hud: HUD = $CanvasLayer/HUD

@export var jar_scene: PackedScene
@export var vyiln_scene: PackedScene

var released_planets: Array[Dictionary] = []

@export var released_planet_friction: float = 180.0
@export var released_planet_spawn_scale: float = 1.8
@export var released_planet_spawn_distance: float = 70.0

const TILE_SIZE := Vector2(240.0, 135.0)
const TILE_SCALE := 8.3
const SCALED_TILE_SIZE := Vector2(240.0 * 8.3, 135.0 * 8.3)

const GRID_COLS := 8
const GRID_ROWS := 8

@export var jar_seek_strength: float = 85.0
@export var jar_max_speed: float = 230.0
@export var jar_arrive_radius: float = 120.0
@export var jar_orbit_strength: float = 52.0
@export var jar_orbit_damping: float = 0.94

@export var chunk_radius: int = 1
@export var star_parallax: float = 0.35
@export var planet_parallax: float = 0.9

@export var camera_radius_x: float = 35.0
@export var camera_radius_y: float = 20.0
@export var camera_speed: float = 0.1

@export var background_shake_distance: float = 24.0
@export var background_shake_start_frequency: float = 34.0
@export var background_shake_end_frequency: float = 120.0
@export var background_shake_smoothness: float = 70.0
@export var background_shake_vertical_multiplier: float = 0.3
@export var background_shake_burst_multiplier: float = 1.15
@export var background_shake_jitter_strength: float = 0.92

@export var released_planet_launch_multiplier: float = 2.2

@export var base_camera_zoom: Vector2 = Vector2.ONE
@export var hyper_charge_zoom: Vector2 = Vector2(2.0, 2.0)
@export var hyper_burst_zoom: Vector2 = Vector2(0.18, 0.18)

@export var zoom_in_lerp_speed: float = 5.5
@export var zoom_out_lerp_speed: float = 60.0
@export var burst_zoom_duration: float = 0.02

@export var enable_gameplay_spawning: bool = true
@export var spawn_enemy_once_only: bool = true

@export var enemy_spawn_interval_min: float = 1.8
@export var enemy_spawn_interval_max: float = 3.8

@export var spawn_radius_min: float = 900.0
@export var spawn_radius_max: float = 1400.0

var enemy_has_spawned_once: bool = false

var current_camera_zoom: Vector2 = Vector2.ONE
var burst_zoom_timer: float = 0.0
var burst_zoom_active: bool = false

var background_shake_time: float = 0.0
var background_shake_offset: Vector2 = Vector2.ZERO

var loaded_chunks: Dictionary = {}
var chunk_texture_map: Dictionary = {}

var screen_size: Vector2
var screen_center: Vector2

var transition_grid_paths: Array[String] = []
var chosen_col: int = 0
var chosen_row: int = 0

var last_center_chunk: Vector2i = Vector2i(999999, 999999)

var camera_time: float = 0.0

var parallax_blend_time: float = 0.0
var parallax_blend_duration: float = 0.6
var parallax_start_position: Vector2 = Vector2.ZERO

var planet_parallax_blend_time: float = 0.0
var planet_parallax_blend_duration: float = 0.6
var planet_parallax_start_position: Vector2 = Vector2.ZERO

var skip_first_process: bool = true

var jar_instances: Array[PlanetJar] = []
var enemy_instances: Array[Node2D] = []

var enemy_spawn_timer: float = 0.0
var next_enemy_spawn_time: float = 0.0

var danger_level: float = 0.0
var survival_time: float = 0.0
var player_damage_recent: float = 0.0
var player_success_recent: float = 0.0
var player_accuracy_recent: float = 0.0


func _ready() -> void:
	randomize()

	if hud != null and game_stats != null:
		hud.setup(game_stats)

	screen_size = get_viewport_rect().size
	screen_center = screen_size * 0.5

	rocket.global_position = screen_center

	transition_grid_paths = TransitionState.selected_game_star_grid_paths.duplicate()
	chosen_col = TransitionState.selected_game_star_tile_col
	chosen_row = TransitionState.selected_game_star_tile_row

	camera_time = TransitionState.game_camera_time
	parallax_start_position = TransitionState.game_star_start_position
	planet_parallax_start_position = screen_center

	planet_manager.planet_ready.connect(_on_planet_ready)

	update_star_chunks(true)

	star_chunks.position = parallax_start_position
	planet_layer.position = planet_parallax_start_position
	jar_layer.position = planet_parallax_start_position
	enemy_layer.position = planet_parallax_start_position

	current_camera_zoom = base_camera_zoom
	camera_2d.zoom = current_camera_zoom
	camera_2d.position = screen_center
	camera_2d.enabled = true
	camera_2d.make_current()

	planet_manager.ensure_starter_planet(rocket.global_position)
	reset_spawn_timers()


func _process(delta: float) -> void:
	screen_size = get_viewport_rect().size
	screen_center = screen_size * 0.5
	camera_2d.position = screen_center

	if skip_first_process:
		skip_first_process = false
		return

	if delta > 0.025:
		print("GAME FRAME SPIKE:", delta)

	camera_time += delta

	update_star_chunks(false)
	update_released_planets(delta)
	update_background_shake(delta)
	update_star_parallax(delta)
	update_planet_parallax(delta)
	update_camera_zoom_fx(delta)

	update_director(delta)
	update_spawn_system(delta)
	update_enemy_cleanup()


func _input(event) -> void:
	if event.is_action_pressed("stop_game"):
		get_tree().quit()


func ease_in_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func get_camera_offset() -> Vector2:
	var angle: float = camera_time * TAU * camera_speed

	return Vector2(
		cos(angle) * camera_radius_x,
		sin(angle) * camera_radius_y
	)


func get_view_world_position() -> Vector2:
	return rocket.world_position


func get_star_world_position() -> Vector2:
	return rocket.world_position * star_parallax


func update_camera_zoom_fx(delta: float) -> void:
	var shake_phase: float = rocket.hyper_manager.get_hyper_shake_strength()
	var target_zoom: Vector2 = base_camera_zoom

	if shake_phase > 0.001:
		var t := shake_phase * shake_phase
		target_zoom = base_camera_zoom.lerp(hyper_charge_zoom, t)

	if burst_zoom_active:
		burst_zoom_timer += delta

		if burst_zoom_timer >= burst_zoom_duration:
			burst_zoom_active = false

		current_camera_zoom = current_camera_zoom.lerp(
			target_zoom,
			min(zoom_out_lerp_speed * delta, 1.0)
		)
	else:
		current_camera_zoom = current_camera_zoom.lerp(
			target_zoom,
			min(zoom_in_lerp_speed * delta, 1.0)
		)

	camera_2d.zoom = current_camera_zoom


func trigger_hyper_zoom_burst() -> void:
	burst_zoom_active = true
	burst_zoom_timer = 0.0
	current_camera_zoom = hyper_burst_zoom
	camera_2d.zoom = current_camera_zoom


func update_director(delta: float) -> void:
	survival_time += delta

	var time_factor: float = clamp(survival_time / 180.0, 0.0, 1.0)
	danger_level = time_factor

	player_damage_recent = move_toward(player_damage_recent, 0.0, delta * 0.15)
	player_success_recent = move_toward(player_success_recent, 0.0, delta * 0.20)
	player_accuracy_recent = move_toward(player_accuracy_recent, 0.0, delta * 0.10)


func reset_spawn_timers() -> void:
	next_enemy_spawn_time = randf_range(enemy_spawn_interval_min, enemy_spawn_interval_max)
	enemy_spawn_timer = 0.0


func update_spawn_system(delta: float) -> void:
	if not enable_gameplay_spawning:
		return

	if spawn_enemy_once_only and enemy_has_spawned_once:
		return

	if _get_alive_enemy_count() > 0:
		return

	enemy_spawn_timer += delta

	if enemy_spawn_timer < next_enemy_spawn_time:
		return

	spawn_vyiln_enemy()

	enemy_has_spawned_once = true
	enemy_spawn_timer = 0.0
	next_enemy_spawn_time = randf_range(enemy_spawn_interval_min, enemy_spawn_interval_max)


func _get_alive_jar_count() -> int:
	var count := 0

	for jar in jar_instances:
		if jar != null and is_instance_valid(jar):
			count += 1

	return count


func _get_alive_enemy_count() -> int:
	var count := 0

	for enemy in enemy_instances:
		if enemy != null and is_instance_valid(enemy):
			count += 1

	return count


func update_enemy_cleanup() -> void:
	for i in range(enemy_instances.size() - 1, -1, -1):
		var enemy := enemy_instances[i]

		if enemy == null or not is_instance_valid(enemy):
			enemy_instances.remove_at(i)


func get_random_spawn_world_position() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(spawn_radius_min, spawn_radius_max)

	return rocket.world_position + Vector2(cos(angle), sin(angle)) * dist


func spawn_vyiln_enemy() -> void:
	if vyiln_scene == null:
		push_warning("vyiln_scene is not assigned.")
		return

	var enemy := vyiln_scene.instantiate() as Node2D

	if enemy == null:
		return

	enemy_layer.add_child(enemy)

	var spawn_pos := get_random_spawn_world_position()

	if enemy.has_method("setup_vyiln"):
		enemy.setup_vyiln(self, rocket, spawn_pos, danger_level)

		if "game_stats" in enemy:
			enemy.game_stats = game_stats

	elif "world_position" in enemy:
		enemy.set("world_position", spawn_pos)
		enemy.position = spawn_pos
	else:
		enemy.position = spawn_pos

	enemy_instances.append(enemy)


func update_star_parallax(delta: float) -> void:
	var star_world_pos: Vector2 = get_star_world_position()
	var ambient_offset: Vector2 = get_camera_offset() * star_parallax
	var target_position: Vector2 = screen_center + ambient_offset - star_world_pos + background_shake_offset

	if parallax_blend_time < parallax_blend_duration:
		parallax_blend_time += delta
		var t: float = ease_in_out(parallax_blend_time / parallax_blend_duration)
		star_chunks.position = parallax_start_position.lerp(target_position, t)
	else:
		star_chunks.position = target_position


func update_planet_parallax(delta: float) -> void:
	var world_pos: Vector2 = get_view_world_position()
	var ambient_offset: Vector2 = get_camera_offset() * planet_parallax
	var target_position: Vector2 = screen_center + ambient_offset - world_pos * planet_parallax + background_shake_offset

	if planet_parallax_blend_time < planet_parallax_blend_duration:
		planet_parallax_blend_time += delta
		var t: float = ease_in_out(planet_parallax_blend_time / planet_parallax_blend_duration)
		planet_layer.position = planet_parallax_start_position.lerp(target_position, t)
	else:
		planet_layer.position = target_position

	jar_layer.position = planet_layer.position
	enemy_layer.position = planet_layer.position

	var holders: Array[Node2D] = planet_manager.get_planet_holders()

	for holder in holders:
		if holder.get_parent() != planet_layer:
			holder.reparent(planet_layer)


func spawn_jar(
	planet_type: String,
	start_world_position: Vector2,
	throw_direction: Vector2,
	throw_hardness: float
) -> void:
	if jar_scene == null:
		push_warning("jar_scene is not assigned.")
		return

	var jar: PlanetJar = jar_scene.instantiate() as PlanetJar

	if jar == null:
		push_warning("Failed to instantiate jar_scene as PlanetJar.")
		return

	jar_layer.add_child(jar)

	var dir := throw_direction.normalized()

	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var spin := throw_hardness * 0.01 * (-1.0 if randf() < 0.5 else 1.0)
	var throw_velocity := dir * throw_hardness

	jar.setup_jar(planet_type, start_world_position, throw_velocity, spin)
	jar.jar_broken.connect(_on_jar_broken)

	jar_instances.append(jar)
	jar.position = jar.world_position


func _on_jar_broken(
	planet_type: String,
	break_world_position: Vector2,
	launch_direction: Vector2,
	launch_strength: float
) -> void:
	if game_stats:
		game_stats.planet_released(planet_type)

	var dir: Vector2 = launch_direction.normalized()

	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	await planet_manager.spawn_new_planet(
		planet_type,
		randi_range(0, 999999),
		break_world_position,
		true
	)

	var holder: Node2D = planet_manager.get_selected_holder()

	if holder == null or not is_instance_valid(holder):
		return

	holder.position = break_world_position

	var size_factor: float = clamp(holder.scale.length(), 0.8, 2.5)
	var launch_multiplier: float = 1.5
	var inverse_size: float = 1.0 / size_factor
	var size_effect: float = lerp(1.0, inverse_size, 0.7)

	var final_velocity: Vector2 = dir * launch_strength * launch_multiplier * size_effect
	var final_scale: Vector2 = holder.scale

	holder.scale = final_scale * released_planet_spawn_scale

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", final_scale, 0.35)

	released_planets.append({
		"holder": holder,
		"velocity": final_velocity
	})


func _on_planet_ready(holder: Node2D) -> void:
	if holder == null or not is_instance_valid(holder):
		return

	if holder.get_parent() != planet_layer:
		holder.reparent(planet_layer)

	_setup_planet_health(holder)
	animate_planet_intro(holder)


func _setup_planet_health(holder: Node2D) -> void:
	var health_component: HealthComponent = holder.get_node_or_null("HealthComponent")

	if health_component == null:
		return

	var planet_type := "Unknown"

	if "type_name" in holder:
		planet_type = holder.get("type_name")
	elif holder.has_meta("type_name"):
		planet_type = str(holder.get_meta("type_name"))

	var size_scale := holder.scale.length() / sqrt(2.0)

	if ClassDB.class_exists("BalanceDatabase"):
		var base_health := 100

		match planet_type:
			"NoAtmosphere":
				base_health = 60
			"GasGiant":
				base_health = 180
			"Star":
				base_health = 300
			_:
				base_health = 120

		var planet_health: int = int(base_health * size_scale)
		
		health_component.setup(planet_health)
	else:
		health_component.setup(max(1, roundi(3.0 + size_scale * 2.0)))


func animate_planet_intro(holder: Node2D) -> void:
	if holder == null or not is_instance_valid(holder):
		return

	var final_scale: Vector2 = holder.scale
	holder.scale = Vector2.ZERO

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", final_scale, 1.15)


func get_center_chunk() -> Vector2i:
	var star_world_pos: Vector2 = get_star_world_position()

	return Vector2i(
		roundi(star_world_pos.x / SCALED_TILE_SIZE.x),
		roundi(star_world_pos.y / SCALED_TILE_SIZE.y)
	)


func update_star_chunks(force: bool) -> void:
	var center_chunk: Vector2i = get_center_chunk()

	if not force and center_chunk == last_center_chunk:
		return

	last_center_chunk = center_chunk

	var needed_chunks: Dictionary = {}

	for y in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
		for x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
			var chunk_coord := Vector2i(x, y)
			needed_chunks[chunk_coord] = true

			if not loaded_chunks.has(chunk_coord):
				create_star_chunk(chunk_coord)

	var to_remove: Array[Vector2i] = []

	for chunk_coord in loaded_chunks.keys():
		if not needed_chunks.has(chunk_coord):
			to_remove.append(chunk_coord)

	for chunk_coord in to_remove:
		var chunk_sprite: Sprite2D = loaded_chunks[chunk_coord]

		if is_instance_valid(chunk_sprite):
			chunk_sprite.queue_free()

		loaded_chunks.erase(chunk_coord)


func create_star_chunk(chunk_coord: Vector2i) -> void:
	var texture_path: String = get_texture_path_for_chunk(chunk_coord)

	if texture_path == "":
		return

	var tex: Texture2D = load(texture_path)

	if tex == null:
		push_warning("Failed to load texture: " + texture_path)
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * TILE_SCALE
	sprite.position = Vector2(
		chunk_coord.x * SCALED_TILE_SIZE.x,
		chunk_coord.y * SCALED_TILE_SIZE.y
	)

	star_chunks.add_child(sprite)
	loaded_chunks[chunk_coord] = sprite


func get_texture_path_for_chunk(chunk_coord: Vector2i) -> String:
	if chunk_texture_map.has(chunk_coord):
		return chunk_texture_map[chunk_coord]

	var grid_col: int = chosen_col + chunk_coord.x
	var grid_row: int = chosen_row + chunk_coord.y

	if grid_col >= 0 and grid_col < GRID_COLS and grid_row >= 0 and grid_row < GRID_ROWS:
		var index: int = grid_row * GRID_COLS + grid_col

		if index >= 0 and index < transition_grid_paths.size():
			var path: String = transition_grid_paths[index]
			chunk_texture_map[chunk_coord] = path
			return path

	var fallback_path: String = get_deterministic_star_path(chunk_coord)
	chunk_texture_map[chunk_coord] = fallback_path

	return fallback_path


func get_deterministic_star_path(chunk_coord: Vector2i) -> String:
	if transition_grid_paths.is_empty():
		return ""

	var key := str(chunk_coord.x, "_", chunk_coord.y)
	var h: int = hash(key)
	var idx: int = int(abs(h)) % transition_grid_paths.size()

	return transition_grid_paths[idx]


func update_background_shake(delta: float) -> void:
	var phase: float = rocket.hyper_manager.get_hyper_shake_strength()
	var t: float = min(background_shake_smoothness * delta, 1.0)

	if phase <= 0.001:
		background_shake_offset = background_shake_offset.lerp(Vector2.ZERO, t)
		return

	var frequency: float = lerp(
		background_shake_start_frequency,
		background_shake_end_frequency,
		phase
	)

	background_shake_time += delta * frequency

	var burst: float = lerp(1.0, background_shake_burst_multiplier, phase)
	var amplitude: float = background_shake_distance * phase * burst

	var base_x := (
		sin(background_shake_time * 1.0)
		+ sin(background_shake_time * 2.2) * 0.35
		+ sin(background_shake_time * 4.6) * 0.12
	) * amplitude

	var base_y := (
		cos(background_shake_time * 1.3)
		+ cos(background_shake_time * 2.8) * 0.28
		+ cos(background_shake_time * 5.0) * 0.10
	) * amplitude * background_shake_vertical_multiplier

	var jitter_amp: float = amplitude * background_shake_jitter_strength

	var jitter := Vector2(
		randf_range(-jitter_amp, jitter_amp),
		randf_range(-jitter_amp, jitter_amp) * background_shake_vertical_multiplier
	)

	var target_offset := Vector2(base_x, base_y) + jitter
	background_shake_offset = background_shake_offset.lerp(target_offset, t)


func update_released_planets(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(released_planets.size()):
		var data: Dictionary = released_planets[i]
		var holder: Node2D = data.get("holder", null)
		var velocity: Vector2 = data.get("velocity", Vector2.ZERO)

		if holder == null or not is_instance_valid(holder):
			to_remove.append(i)
			continue

		holder.position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, released_planet_friction * delta)

		data["velocity"] = velocity
		released_planets[i] = data

		if velocity.length() <= 1.0:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		released_planets.remove_at(to_remove[i])

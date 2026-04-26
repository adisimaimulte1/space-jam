extends Node2D

signal planet_ready(holder: Node2D)

var planet_scenes: Dictionary = {}
var planet_type_names: Array[String] = []
var starter_planet_type_names: Array[String] = []

var planet_instances: Array[Dictionary] = []
var selected_planet_index: int = -1

func _ready() -> void:
	randomize()
	planet_scenes = PlanetData.get_planet_scenes()
	planet_type_names = PlanetData.get_planet_type_names()
	starter_planet_type_names = PlanetData.get_starter_planet_type_names()

func _process(delta: float) -> void:
	for i in range(planet_instances.size()):
		var data: Dictionary = planet_instances[i]
		var holder: Node2D = data.get("holder", null)

		if holder == null or not is_instance_valid(holder):
			continue

		if data.get("type_name", "") == "NoAtmosphere":
			update_moon_instance(data, delta)
			planet_instances[i] = data

func ensure_starter_planet(at_world_position: Vector2) -> void:
	if not planet_instances.is_empty():
		return

	var random_type: String = starter_planet_type_names[randi() % starter_planet_type_names.size()]
	await spawn_new_planet(random_type, randi_range(0, 999999), at_world_position, true)

func get_selected_data() -> Dictionary:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return {}
	return planet_instances[selected_planet_index]

func get_selected_holder() -> Node2D:
	var data: Dictionary = get_selected_data()
	return data.get("holder", null)

func get_selected_type_name() -> String:
	var data: Dictionary = get_selected_data()
	return data.get("type_name", "")

func get_selected_seed() -> int:
	var data: Dictionary = get_selected_data()
	return data.get("seed", 0)

func get_selected_config() -> Dictionary:
	var data: Dictionary = get_selected_data()
	return data.get("config", {})

func get_planet_holders() -> Array[Node2D]:
	var holders: Array[Node2D] = []
	for data in planet_instances:
		var holder: Node2D = data.get("holder", null)
		if holder != null and is_instance_valid(holder):
			holders.append(holder)
	return holders

func select_next_planet() -> void:
	if planet_instances.is_empty():
		selected_planet_index = -1
		return

	selected_planet_index += 1
	if selected_planet_index >= planet_instances.size():
		selected_planet_index = 0

	debug_print_selected()

func select_previous_planet() -> void:
	if planet_instances.is_empty():
		selected_planet_index = -1
		return

	selected_planet_index -= 1
	if selected_planet_index < 0:
		selected_planet_index = planet_instances.size() - 1

	debug_print_selected()

func spawn_random_starter_planet(at_position: Vector2 = Vector2.ZERO, select_new: bool = true) -> void:
	var random_type: String = starter_planet_type_names[randi() % starter_planet_type_names.size()]
	await spawn_new_planet(random_type, randi_range(0, 999999), at_position, select_new)

func spawn_random_planet(at_position: Vector2 = Vector2.ZERO, select_new: bool = true) -> void:
	var random_type: String = planet_type_names[randi() % planet_type_names.size()]
	await spawn_new_planet(random_type, randi_range(0, 999999), at_position, select_new)

func spawn_new_planet(type_name: String, seed_value: int, world_position: Vector2, select_new: bool = true) -> void:
	if not planet_scenes.has(type_name):
		push_error("Unknown planet type: " + type_name)
		return

	var holder := Node2D.new()
	holder.name = "PlanetHolder_%d" % planet_instances.size()
	add_child(holder)

	var cfg: Dictionary = PlanetData.get_type_config(type_name).duplicate(true)
	var palette: Array[Color] = PlanetData.get_palette(type_name)

	var spawn_result: Dictionary = await PlanetSpawner.spawn_system(
		self,
		holder,
		planet_scenes,
		type_name,
		palette,
		seed_value,
		cfg
	)

	holder.position = world_position
	holder.z_index = _get_planet_z_index(type_name)

	var instance := {
		"holder": holder,
		"current_planet": spawn_result.get("current_planet", null),
		"type_name": type_name,
		"seed": seed_value,
		"config": cfg,
		"final_scale": spawn_result.get("final_scale", Vector2.ONE),
		"star_instability": 0,
		"star_is_critical": false,
		"moon_drift_velocity": _generate_moon_drift_velocity(cfg),
		"moon_orbit_angle": randf() * TAU,
		"moon_orbit_speed": randf_range(
			cfg.get("orbit_speed_min", 0.14),
			cfg.get("orbit_speed_max", 0.32)
		),
		"moon_orbit_radius": -1.0,
		"moon_target_holder": null
	}

	planet_instances.append(instance)

	if select_new:
		selected_planet_index = planet_instances.size() - 1

	planet_ready.emit(holder)

func respawn_same_type_new_seed() -> void:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return

	var type_name: String = planet_instances[selected_planet_index]["type_name"]
	await replace_selected_planet(type_name, randi_range(0, 999999))

func replace_selected_planet(type_name: String, seed_value: int) -> void:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return

	if not planet_scenes.has(type_name):
		push_error("Unknown planet type: " + type_name)
		return

	var old_data: Dictionary = planet_instances[selected_planet_index]
	var old_holder: Node2D = old_data.get("holder", null)
	if old_holder == null or not is_instance_valid(old_holder):
		return

	var old_parent: Node = old_holder.get_parent()
	var old_position: Vector2 = old_holder.position

	old_holder.queue_free()

	var holder := Node2D.new()
	holder.name = "PlanetHolder_%d" % selected_planet_index
	holder.position = old_position

	if old_parent != null:
		old_parent.add_child(holder)
	else:
		add_child(holder)

	var cfg: Dictionary = PlanetData.get_type_config(type_name).duplicate(true)
	var palette: Array[Color] = PlanetData.get_palette(type_name)

	var spawn_result: Dictionary = await PlanetSpawner.spawn_system(
		self,
		holder,
		planet_scenes,
		type_name,
		palette,
		seed_value,
		cfg
	)

	planet_instances[selected_planet_index] = {
		"holder": holder,
		"current_planet": spawn_result.get("current_planet", null),
		"type_name": type_name,
		"seed": seed_value,
		"config": cfg,
		"final_scale": spawn_result.get("final_scale", Vector2.ONE),
		"star_instability": 0,
		"star_is_critical": false,
		"moon_drift_velocity": _generate_moon_drift_velocity(cfg),
		"moon_orbit_angle": randf() * TAU,
		"moon_orbit_speed": randf_range(
			cfg.get("orbit_speed_min", 0.14),
			cfg.get("orbit_speed_max", 0.32)
		),
		"moon_orbit_radius": -1.0,
		"moon_target_holder": null
	}

	planet_ready.emit(holder)
	debug_print_selected()

func spawn_next_type() -> void:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return

	var current_type: String = get_selected_type_name()
	var idx: int = planet_type_names.find(current_type)
	if idx < 0:
		idx = 0

	idx += 1
	if idx >= planet_type_names.size():
		idx = 0

	await replace_selected_planet(planet_type_names[idx], randi_range(0, 999999))

func delete_selected_planet() -> void:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return

	var data: Dictionary = planet_instances[selected_planet_index]
	var holder: Node2D = data.get("holder", null)
	if holder != null and is_instance_valid(holder):
		holder.queue_free()

	planet_instances.remove_at(selected_planet_index)

	if planet_instances.is_empty():
		selected_planet_index = -1
	else:
		selected_planet_index = clampi(selected_planet_index, 0, planet_instances.size() - 1)

	debug_print_selected()

func update_moon_instance(data: Dictionary, delta: float) -> void:
	var holder: Node2D = data.get("holder", null)
	if holder == null or not is_instance_valid(holder):
		return

	var cfg: Dictionary = data.get("config", {})

	var target: Node2D = data.get("moon_target_holder", null)
	if target == null or not is_instance_valid(target):
		target = _get_nearest_possible_moon_holder(holder)
		data["moon_target_holder"] = target
		data["moon_orbit_radius"] = -1.0
		data["moon_is_orbiting"] = false

	if target == null:
		return

	# INIT VELOCITY
	var velocity: Vector2 = data.get("moon_velocity", Vector2.ZERO)

	var to_planet: Vector2 = target.position - holder.position
	var dist: float = to_planet.length()
	if dist <= 0.001:
		return

	var planet_radius: float = _estimate_holder_radius(target)
	var moon_radius: float = _estimate_holder_radius(holder)

	var desired_orbit_radius: float = data.get("moon_orbit_radius", -1.0)
	if desired_orbit_radius <= 0.0:
		var orbit_padding_min: float = cfg.get("orbit_padding_min", 80.0)
		var orbit_padding_max: float = cfg.get("orbit_padding_max", 180.0)
		desired_orbit_radius = planet_radius + moon_radius + randf_range(orbit_padding_min, orbit_padding_max)
		data["moon_orbit_radius"] = desired_orbit_radius

	var orbit_snap_band: float = cfg.get("orbit_snap_band", 24.0)
	var seek_speed: float = cfg.get("seek_speed", 220.0)

	var orbit_speed: float = data.get("moon_orbit_speed", 0.2) * 1.4

	var orbit_angle: float = data.get("moon_orbit_angle", 0.0)
	var is_orbiting: bool = data.get("moon_is_orbiting", false)

	var dir: Vector2 = to_planet.normalized()
	var radial_error: float = dist - desired_orbit_radius

	# CHASE PHASE
	if not is_orbiting:
		if abs(radial_error) <= orbit_snap_band:
			data["moon_is_orbiting"] = true

			var offset: Vector2 = holder.position - target.position
			data["moon_orbit_angle"] = offset.angle()

		# target velocity toward orbit ring
		var target_velocity: Vector2

		if radial_error > 0.0:
			target_velocity = dir * seek_speed
		else:
			target_velocity = -dir * seek_speed

		velocity = velocity.lerp(target_velocity, delta * 4.0)

		holder.position += velocity * delta
		data["moon_velocity"] = velocity
		return

	# ORBIT PHASE 
	orbit_angle += orbit_speed * delta
	data["moon_orbit_angle"] = orbit_angle

	var tangent: Vector2 = Vector2(-sin(orbit_angle), cos(orbit_angle))
	var orbit_velocity: Vector2 = tangent * seek_speed * 0.8  # match feel

	velocity = velocity.lerp(orbit_velocity, delta * 3.0)

	holder.position += velocity * delta

	var desired_pos = target.position + (holder.position - target.position).normalized() * desired_orbit_radius
	holder.position = holder.position.lerp(desired_pos, delta * 2.0)

	data["moon_velocity"] = velocity
	
func _get_nearest_possible_moon_holder(source_holder: Node2D) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	var forbidden_types := ["NoAtmosphere", "Star", "Galaxy", "BlackHole"]

	for data in planet_instances:
		var type_name: String = data.get("type_name", "")
		if type_name in forbidden_types:
			continue

		var holder: Node2D = data.get("holder", null)
		if holder == null or not is_instance_valid(holder):
			continue

		if holder == source_holder:
			continue

		var dist := source_holder.global_position.distance_to(holder.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = holder

	return nearest
	
func _generate_moon_drift_velocity(cfg: Dictionary) -> Vector2:
	var angle := randf() * TAU
	var speed := randf_range(
		cfg.get("drift_speed_min", 25.0),
		cfg.get("drift_speed_max", 55.0)
	)
	return Vector2(cos(angle), sin(angle)) * speed

func _estimate_holder_radius(holder: Node2D) -> float:
	if holder == null or not is_instance_valid(holder):
		return 100.0

	var type_name: String = ""
	for data in planet_instances:
		if data.get("holder", null) == holder:
			type_name = data.get("type_name", "")
			break

	var rect := holder.get_node_or_null("DebugBounds")
	if rect != null and rect is Control:
		var size: Vector2 = rect.size
		if type_name == "NoAtmosphere":
			return max(size.x, size.y) * 0.35
		return max(size.x, size.y) * 0.5

	return 100.0
	
func get_effect_at_position(world_pos: Vector2) -> Dictionary:
	var best_effect := {
		"type": "",
		"effect_type": "",
		"strength": 0.0,
		"config": {},
		"world_position": Vector2.ZERO
	}

	for data in planet_instances:
		var holder: Node2D = data.get("holder", null)
		if holder == null or not is_instance_valid(holder):
			continue

		var effect := PlanetEffects.get_effect_at_position(
			data.get("type_name", ""),
			data.get("config", {}),
			holder.global_position,
			world_pos
		)

		if effect["strength"] > best_effect["strength"]:
			best_effect = effect

	return best_effect

func get_speed_multiplier_at_position(world_pos: Vector2) -> float:
	var effect: Dictionary = get_effect_at_position(world_pos)
	return PlanetEffects.get_speed_multiplier(
		effect["type"],
		effect["config"],
		effect["strength"]
	)

func get_heal_per_second_at_position(world_pos: Vector2) -> float:
	var effect: Dictionary = get_effect_at_position(world_pos)
	return PlanetEffects.get_heal_per_second(
		effect["type"],
		effect["config"],
		effect["strength"]
	)

func get_burn_damage_per_second_at_position(world_pos: Vector2) -> float:
	var effect: Dictionary = get_effect_at_position(world_pos)
	return PlanetEffects.get_burn_dps(
		effect["type"],
		effect["config"],
		effect["strength"]
	)

func get_gravity_pull_vector(world_pos: Vector2) -> Vector2:
	var total := Vector2.ZERO

	for data in planet_instances:
		var holder: Node2D = data.get("holder", null)
		if holder == null or not is_instance_valid(holder):
			continue

		var effect := PlanetEffects.get_effect_at_position(
			data.get("type_name", ""),
			data.get("config", {}),
			holder.global_position,
			world_pos
		)

		total += PlanetEffects.get_gravity_pull(
			effect["type"],
			effect["config"],
			effect["strength"],
			world_pos,
			effect["world_position"]
		)

	return total

func is_in_any_star_absorb_radius(world_pos: Vector2) -> bool:
	for data in planet_instances:
		var holder: Node2D = data.get("holder", null)
		if holder == null or not is_instance_valid(holder):
			continue

		if PlanetEffects.is_in_star_absorb_radius(
			data.get("type_name", ""),
			data.get("config", {}),
			holder.global_position,
			world_pos
		):
			return true

	return false

func feed_selected_star(amount: int = 1) -> void:
	if selected_planet_index < 0 or selected_planet_index >= planet_instances.size():
		return

	var data: Dictionary = planet_instances[selected_planet_index]
	if data.get("type_name", "") != "Star":
		return

	if data.get("star_is_critical", false):
		return

	var instability: int = data.get("star_instability", 0)
	instability += amount
	data["star_instability"] = instability

	var threshold: int = data.get("config", {}).get("instability_threshold", 25)
	if instability >= threshold:
		data["star_is_critical"] = true

	planet_instances[selected_planet_index] = data

func debug_print_selected() -> void:
	var data: Dictionary = get_selected_data()
	if data.is_empty():
		print("No selected planet.")
		return

	print(
		"Selected planet | index: ", selected_planet_index,
		" | type: ", data.get("type_name", ""),
		" | seed: ", data.get("seed", 0),
		" | effect: ", data.get("config", {}).get("effect_type", "none")
	)
	
func _get_planet_z_index(type_name: String) -> int:
	match type_name:
		"Star", "BlackHole":
			return 12
		"NoAtmosphere":
			return 21
		_:
			return 15

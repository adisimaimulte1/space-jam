# PlanetEffects.gd
extends RefCounted
class_name PlanetEffects

static func get_strength(world_pos: Vector2, planet_pos: Vector2, radius: float) -> float:
	if radius <= 0.0:
		return 0.0

	var dist := world_pos.distance_to(planet_pos)
	if dist >= radius:
		return 0.0

	return 1.0 - (dist / radius)

static func get_effect_at_position(type_name: String, cfg: Dictionary, planet_pos: Vector2, world_pos: Vector2) -> Dictionary:
	var radius: float = cfg.get("influence_radius", 0.0)
	var strength := get_strength(world_pos, planet_pos, radius)

	return {
		"type": type_name,
		"effect_type": cfg.get("effect_type", ""),
		"strength": strength,
		"config": cfg,
		"world_position": planet_pos
	}

static func get_speed_multiplier(type_name: String, cfg: Dictionary, strength: float) -> float:
	if strength <= 0.0:
		return 1.0

	match type_name:
		"IceWorld":
			var outer_slow: float = cfg.get("slow_outer", 0.10)
			var inner_slow: float = cfg.get("slow_inner", 0.20)
			var slow_amount: float = lerp(outer_slow, inner_slow, strength)
			return 1.0 - slow_amount
		_:
			return 1.0

static func get_heal_per_second(type_name: String, cfg: Dictionary, strength: float) -> float:
	if strength <= 0.0:
		return 0.0

	match type_name:
		"LandMasses":
			return cfg.get("regen_rate", 4.0) * strength
		_:
			return 0.0

static func get_burn_dps(type_name: String, cfg: Dictionary, strength: float) -> float:
	if strength <= 0.0:
		return 0.0

	match type_name:
		"LavaWorld":
			return cfg.get("burn_dps", 8.0) * strength
		_:
			return 0.0

static func get_gravity_pull(type_name: String, cfg: Dictionary, strength: float, world_pos: Vector2, planet_pos: Vector2) -> Vector2:
	if strength <= 0.0:
		return Vector2.ZERO

	match type_name:
		"BlackHole":
			var dir := (planet_pos - world_pos).normalized()
			return dir * cfg.get("pull_strength", 1100.0) * strength

		"GasPlanet", "GasPlanetLayers":
			var to_planet := planet_pos - world_pos
			if to_planet.length() <= 0.001:
				return Vector2.ZERO
			var tangent := Vector2(-to_planet.y, to_planet.x).normalized()
			return tangent * cfg.get("flow_strength", 320.0) * strength

		_:
			return Vector2.ZERO

static func is_in_star_absorb_radius(type_name: String, cfg: Dictionary, planet_pos: Vector2, world_pos: Vector2) -> bool:
	if type_name != "Star":
		return false

	var absorb_radius: float = cfg.get("absorb_radius", 1100.0)
	return world_pos.distance_to(planet_pos) <= absorb_radius

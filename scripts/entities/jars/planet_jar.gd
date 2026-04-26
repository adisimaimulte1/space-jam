extends Area2D
class_name PlanetJar

signal jar_broken(planet_type: String, world_position: Vector2, launch_direction: Vector2, launch_strength: float)

@onready var jar_sprite: AnimatedSprite2D = $JarSprite
@onready var jam_sprite: AnimatedSprite2D = $JamSprite
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var planet_type: String = "LandMasses"
@export var jar_z_index: int = 22

@export var drag: float = 6.0
@export var angular_drag: float = 0.0

@export var spin_min: float = 0.12
@export var spin_max: float = 0.45
@export var throw_spin_multiplier: float = 0.0015

@export var break_shake_duration: float = 0.18
@export var break_shake_strength: float = 7.0
@export var break_scale_duration: float = 0.18
@export var break_target_scale: float = 0.65

@export var explosion_scale_multiplier: float = 2.5

@export var spit_strength_multiplier: float = 1.0
@export var fallback_spit_strength: float = 220.0

var PLANET_COLOR_MAP := {
	"BlackHole": "black",
	"DryTerran": "brown",
	"Galaxy": "purple3",
	"GasPlanet": "purple3",
	"GasPlanetLayers": "orange<",
	"IceWorld": "blue",
	"LandMasses": "green",
	"LavaWorld": "red",
	"NoAtmosphere": "grey",
	"Rivers": "green",
	"Star": "yellow"
}

var world_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0

var broken: bool = false
var breaking: bool = false

var _base_scale: Vector2 = Vector2.ONE
var _base_jar_pos: Vector2
var _base_jam_pos: Vector2
var _base_explosion_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	z_index = jar_z_index
	z_as_relative = false

	_base_scale = scale
	_base_jar_pos = jar_sprite.position
	_base_jam_pos = jam_sprite.position
	_base_explosion_scale = explosion_sprite.scale

	explosion_sprite.visible = false
	explosion_sprite.stop()

	_apply_planet_visuals()

	if explosion_sprite.sprite_frames and not explosion_sprite.animation_finished.is_connected(_on_explosion_finished):
		explosion_sprite.animation_finished.connect(_on_explosion_finished)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func update_jar(delta: float) -> void:
	if broken or breaking:
		return

	world_position += velocity * delta
	rotation += angular_velocity * delta

	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

func setup_jar(
	p_type: String,
	start_world_position: Vector2,
	throw_velocity: Vector2 = Vector2.ZERO,
	throw_spin: float = 0.0
) -> void:
	planet_type = p_type
	world_position = start_world_position
	position = world_position
	velocity = throw_velocity
	
	z_index = jar_z_index
	z_as_relative = false

	var spin_sign := -1.0 if randf() < 0.5 else 1.0
	var base_spin := randf_range(spin_min, spin_max)
	angular_velocity = (base_spin + throw_velocity.length() * throw_spin_multiplier + abs(throw_spin) * 0.15) * spin_sign

	_apply_planet_visuals()

func throw_in_space(direction: Vector2, hardness: float) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	velocity = dir * hardness * 0.18

	var spin_sign := -1.0 if randf() < 0.5 else 1.0
	var base_spin := randf_range(spin_min, spin_max)
	angular_velocity = (base_spin + hardness * throw_spin_multiplier) * spin_sign

func _apply_planet_visuals() -> void:
	if jar_sprite.sprite_frames:
		if jar_sprite.sprite_frames.has_animation("idle"):
			jar_sprite.play("idle")
		else:
			jar_sprite.play()

	var jam_anim: String = _get_jam_animation_for_planet(planet_type)

	if jam_sprite.sprite_frames:
		if jam_sprite.sprite_frames.has_animation(jam_anim):
			jam_sprite.play(jam_anim)
		elif jam_sprite.sprite_frames.has_animation("grey"):
			jam_sprite.play("grey")
		else:
			jam_sprite.play()

func _get_jam_animation_for_planet(type_name: String) -> String:
	if PLANET_COLOR_MAP.has(type_name):
		return PLANET_COLOR_MAP[type_name]

	var lowered := type_name.to_lower()

	if "black" in lowered:
		return "black"
	if "dry" in lowered or "desert" in lowered or "terran" in lowered:
		return "orange<"
	if "galaxy" in lowered:
		return "purple3"
	if "gas" in lowered:
		return "yellow"
	if "ice" in lowered or "frozen" in lowered:
		return "blue"
	if "land" in lowered or "forest" in lowered or "earth" in lowered:
		return "green"
	if "lava" in lowered or "fire" in lowered or "molten" in lowered:
		return "red"
	if "river" in lowered:
		return "green"
	if "water" in lowered or "ocean" in lowered:
		return "blue"
	if "star" in lowered or "sun" in lowered:
		return "yellow"
	if "atmosphere" in lowered or "moon" in lowered or "rock" in lowered:
		return "grey"

	return "grey"

func _on_area_entered(area: Area2D) -> void:
	if broken or breaking:
		return

	if area.is_in_group("player_bullet"):
		var hit_dir: Vector2 = _extract_hit_direction_from_area(area)
		var hit_strength: float = _extract_hit_strength_from_area(area, velocity.length())
		break_jar(hit_dir, hit_strength)
	elif area.is_in_group("player_vortex"):
		var hit_dir: Vector2 = _extract_hit_direction_from_area(area)
		var hit_strength: float = _extract_hit_strength_from_area(area, max(velocity.length(), 300.0))
		break_jar(hit_dir, hit_strength)

func _on_body_entered(body: Node) -> void:
	if broken or breaking:
		return

	if body.is_in_group("player_bullet"):
		var hit_dir: Vector2 = _extract_hit_direction_from_body(body)
		var hit_strength: float = _extract_hit_strength_from_body(body, velocity.length())
		break_jar(hit_dir, hit_strength)
	elif body.is_in_group("player_vortex"):
		var hit_dir: Vector2 = _extract_hit_direction_from_body(body)
		var hit_strength: float = _extract_hit_strength_from_body(body, max(velocity.length(), 300.0))
		break_jar(hit_dir, hit_strength)

func break_jar(hit_direction: Vector2, hit_strength: float = 0.0) -> void:
	if broken or breaking:
		return

	breaking = true
	collision_shape.set_deferred("disabled", true)

	var dir := hit_direction.normalized()
	if dir == Vector2.ZERO:
		if velocity.length() > 0.0:
			dir = velocity.normalized()
		else:
			dir = Vector2.RIGHT

	velocity = Vector2.ZERO
	angular_velocity = 0.0

	await _play_break_squash_and_shake()

	jar_sprite.visible = false
	jam_sprite.visible = false

	explosion_sprite.visible = true
	explosion_sprite.scale = _base_explosion_scale * explosion_scale_multiplier

	_emit_planet_release(dir, hit_strength)

	if explosion_sprite.sprite_frames:
		if explosion_sprite.sprite_frames.has_animation("break"):
			explosion_sprite.play("break")
		else:
			explosion_sprite.play()
	else:
		queue_free()

func _emit_planet_release(hit_direction: Vector2, hit_strength: float) -> void:
	var dir := hit_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var strength: float = max(hit_strength * spit_strength_multiplier, fallback_spit_strength)
	emit_signal("jar_broken", planet_type, world_position, dir, strength)

func _play_break_squash_and_shake() -> void:
	var elapsed := 0.0

	while elapsed < break_shake_duration:
		var t := elapsed / break_shake_duration
		var inv := 1.0 - t

		var shake_offset := Vector2(
			randf_range(-break_shake_strength, break_shake_strength),
			randf_range(-break_shake_strength, break_shake_strength)
		) * inv

		var s: float = lerp(1.0, break_target_scale, min(elapsed / break_scale_duration, 1.0))
		scale = _base_scale * s

		jar_sprite.position = _base_jar_pos + shake_offset
		jam_sprite.position = _base_jam_pos + shake_offset

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	scale = _base_scale * break_target_scale
	jar_sprite.position = _base_jar_pos
	jam_sprite.position = _base_jam_pos

func _on_explosion_finished() -> void:
	broken = true
	queue_free()

func _extract_hit_direction_from_area(area: Area2D) -> Vector2:
	if "velocity" in area:
		var v = area.velocity
		if v is Vector2 and v.length() > 0.0:
			return v.normalized()

	if "direction" in area:
		var d = area.direction
		if d is Vector2 and d.length() > 0.0:
			return d.normalized()

	return (global_position - area.global_position).normalized()

func _extract_hit_direction_from_body(body: Node) -> Vector2:
	if "velocity" in body:
		var v = body.velocity
		if v is Vector2 and v.length() > 0.0:
			return v.normalized()

	if "direction" in body:
		var d = body.direction
		if d is Vector2 and d.length() > 0.0:
			return d.normalized()

	if body is Node2D:
		return (global_position - body.global_position).normalized()

	return Vector2.RIGHT

func _extract_hit_strength_from_area(area: Area2D, fallback: float) -> float:
	if "velocity" in area:
		var v = area.velocity
		if v is Vector2:
			return v.length()

	if "hit_strength" in area:
		var h = area.hit_strength
		if h is float or h is int:
			return float(h)

	return max(fallback, fallback_spit_strength)

func _extract_hit_strength_from_body(body: Node, fallback: float) -> float:
	if "velocity" in body:
		var v = body.velocity
		if v is Vector2:
			return v.length()

	if "hit_strength" in body:
		var h = body.hit_strength
		if h is float or h is int:
			return float(h)

	return max(fallback, fallback_spit_strength)

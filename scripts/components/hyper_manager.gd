extends Node
class_name HyperManager

var rocket: CharacterBody2D

var charge: float = 0.0
var transitioning: bool = false
var active: bool = false
var waiting_for_trigger_release: bool = false

var transition_target_active: bool = false
var transition_progress: float = 0.0
var shake_out: float = 0.0

@export var charge_time: float = 0.8
@export var decay_time: float = 0.35
@export var transition_time: float = 0.7
@export var extension_offset: Vector2 = Vector2(0, 25)
@export var min_charge_scale: float = 0.85
@export var hyper_explosion_scale: float = 4.0

func setup(r: CharacterBody2D) -> void:
	rocket = r

	if not rocket.hyper_explosion.animation_finished.is_connected(_on_hyper_explosion_animation_finished):
		rocket.hyper_explosion.animation_finished.connect(_on_hyper_explosion_animation_finished)

func update(delta: float) -> void:
	var trigger: float = Input.get_action_strength("hyper_charge")

	if transitioning:
		transition_progress = move_toward(transition_progress, 1.0, delta / transition_time)
		shake_out = transition_progress
		return

	if waiting_for_trigger_release:
		charge = 0.0

		if trigger <= 0.1:
			waiting_for_trigger_release = false

		return

	if trigger > 0.1:
		charge = move_toward(charge, 1.0, delta / charge_time)

		if charge >= 1.0:
			charge = 1.0
			start_transition(not active)
	else:
		charge = move_toward(charge, 0.0, delta / decay_time)

func start_transition(target_active: bool) -> void:
	transitioning = true
	waiting_for_trigger_release = true
	transition_target_active = target_active
	transition_progress = 0.0
	shake_out = 0.0
	charge = 1.0
	
	var game := rocket.get_parent()
	if game != null and game.has_method("trigger_hyper_zoom_burst"):
		game.trigger_hyper_zoom_burst()

	rocket.body_sprite.visible = false
	rocket.flame_sprite.visible = false
	rocket.hyper_extension.visible = false

	rocket.hyper_explosion.visible = true
	rocket.hyper_explosion.scale = Vector2.ONE * hyper_explosion_scale
	rocket.hyper_explosion.frame = 0

	rocket.stop_all_engine_sfx()

	if rocket.hyper_charge_sfx and rocket.hyper_charge_sfx.playing:
		rocket.hyper_charge_sfx.stop()

	if rocket.hyper_burst_sfx:
		rocket.hyper_burst_sfx.volume_db = -8.0
		rocket.hyper_burst_sfx.play()

	if rocket.hyper_explosion.sprite_frames != null:
		if rocket.hyper_explosion.sprite_frames.has_animation("burst"):
			rocket.hyper_explosion.play("burst")
		elif rocket.hyper_explosion.sprite_frames.has_animation("default"):
			rocket.hyper_explosion.play("default")
			
func _on_hyper_explosion_animation_finished() -> void:
	if not transitioning:
		rocket.hyper_explosion.visible = false
		return

	finish()

func finish() -> void:
	transitioning = false
	active = transition_target_active
	charge = 0.0
	transition_progress = 0.0
	shake_out = 0.0

	rocket.hyper_explosion.stop()
	rocket.hyper_explosion.visible = false

	rocket.body_sprite.visible = true
	rocket.flame_sprite.visible = true

	if active:
		rocket.hyper_extension.visible = true

		if rocket.hyper_extension.sprite_frames != null:
			if rocket.hyper_extension.sprite_frames.has_animation("active"):
				rocket.hyper_extension.play("active")
			elif rocket.hyper_extension.sprite_frames.has_animation("idle"):
				rocket.hyper_extension.play("idle")
	else:
		rocket.hyper_extension.visible = false
		rocket.hyper_extension.stop()

func get_hyper_shake_strength() -> float:
	if transitioning:
		return 1.0 - shake_out
	return charge

func get_rocket_visual_scale() -> float:
	if transitioning:
		return lerp(min_charge_scale, 1.0, transition_progress)

	return lerp(1.0, min_charge_scale, charge)

func get_scaled_extension_offset() -> Vector2:
	return extension_offset * get_rocket_visual_scale()

func is_hyper_transitioning() -> bool:
	return transitioning

func is_hyper_active() -> bool:
	return active

func get_hyper_ready() -> bool:
	return false

func get_hyper_charge_ratio() -> float:
	return charge

func is_exploding() -> bool:
	return transitioning and rocket.hyper_explosion.visible

extends CharacterBody2D

@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var flame_sprite: AnimatedSprite2D = $FlameSprite
@onready var bullet_spawn: Marker2D = $BulletSpawn
@onready var hyper_extension: AnimatedSprite2D = $HyperExtension
@onready var hyper_explosion: AnimatedSprite2D = $HyperExplosion
@onready var hyper_manager: HyperManager = $HyperManager

@onready var explosion_hitbox: Area2D = $HyperExplosion/ExplosionHitbox
@onready var explosion_hitbox_shape: CollisionShape2D = $HyperExplosion/ExplosionHitbox/CollisionShape2D

@onready var thrust_sfx: AudioStreamPlayer2D = $ThrustSFX
@onready var shoot_sfx: AudioStreamPlayer2D = $ShootSFX
@onready var hyper_charge_sfx: AudioStreamPlayer2D = $HyperChargeSFX
@onready var hyper_burst_sfx: AudioStreamPlayer2D = $HyperBurstSFX
@onready var hyper_off_sfx: AudioStreamPlayer2D = $HyperOffSFX

@export var max_speed: float = 500.0
@export var acceleration: float = 900.0
@export var friction: float = 200.0
@export var rotation_lerp_speed: float = 4.0
@export var deadzone: float = 0.15
@export var min_turn_velocity: float = 10.0
@export var sprite_rotation_offset: float = PI / 2.0

@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.3
@export var hyper_speed_multiplier: float = 1.55
@export var hyper_acceleration_multiplier: float = 1.35

var input_vector: Vector2 = Vector2.ZERO
var last_move_input: Vector2 = Vector2.RIGHT
var thrusting := false
var was_thrusting := false
var was_hyper_transitioning := false
var was_hyper_active := false
var was_charging := false
var explosion_hitbox_enabled := false

var world_position: Vector2 = Vector2.ZERO

var can_shoot := true
var shoot_cooldown_left := 0.0

var base_flame_position: Vector2
var base_extension_position: Vector2

func _ready() -> void:
	randomize()

	z_index = 100

	base_flame_position = flame_sprite.position
	base_extension_position = hyper_extension.position

	body_sprite.play("idle")
	flame_sprite.play("off")

	hyper_extension.visible = false
	hyper_explosion.visible = false

	if not flame_sprite.animation_finished.is_connected(_on_flame_sprite_animation_finished):
		flame_sprite.animation_finished.connect(_on_flame_sprite_animation_finished)

	if not hyper_explosion.animation_finished.is_connected(_on_hyper_explosion_animation_finished):
		hyper_explosion.animation_finished.connect(_on_hyper_explosion_animation_finished)

	explosion_hitbox.add_to_group("player_vortex")
	disable_explosion_hitbox()

	hyper_manager.setup(self)

func _physics_process(delta: float) -> void:
	read_input()
	hyper_manager.update(delta)
	update_hyper_sfx()
	update_hyper_visuals()
	update_movement(delta)
	update_rotation(delta)
	update_flame_animation()
	update_shooting(delta)
	update_explosion_hitbox_state()

	world_position += velocity * delta
	global_position = get_viewport_rect().size * 0.5

func read_input() -> void:
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector.length() < deadzone:
		input_vector = Vector2.ZERO
	else:
		last_move_input = input_vector.normalized()

func update_movement(delta: float) -> void:
	var speed_mul := 1.0
	var accel_mul := 1.0

	if hyper_manager.is_exploding():
		speed_mul *= 3.0
		accel_mul *= 3.0
	elif hyper_manager.is_hyper_active():
		speed_mul *= hyper_speed_multiplier
		accel_mul *= hyper_acceleration_multiplier

	if input_vector != Vector2.ZERO:
		var target := input_vector * max_speed * speed_mul
		velocity = velocity.move_toward(target, acceleration * accel_mul * delta)
		thrusting = true
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		thrusting = false

func update_rotation(delta: float) -> void:
	var dir := Vector2.ZERO

	if input_vector != Vector2.ZERO:
		dir = input_vector.normalized()
	elif velocity.length() > min_turn_velocity:
		dir = velocity.normalized()
	else:
		dir = last_move_input

	if dir == Vector2.ZERO:
		return

	var target := dir.angle() + sprite_rotation_offset
	rotation = lerp_angle(rotation, target, rotation_lerp_speed * delta)

func update_flame_animation() -> void:
	if hyper_manager.is_hyper_transitioning():
		return

	if thrusting != was_thrusting:
		if thrusting:
			flame_sprite.play("start")
		else:
			flame_sprite.play("stop")

	was_thrusting = thrusting

func update_shooting(delta: float) -> void:
	if hyper_manager.is_hyper_transitioning():
		return

	if not can_shoot:
		shoot_cooldown_left -= delta
		if shoot_cooldown_left <= 0.0:
			can_shoot = true

	if Input.is_action_just_pressed("shoot") and can_shoot:
		shoot_bullet()
		can_shoot = false
		shoot_cooldown_left = shoot_cooldown

func shoot_bullet() -> void:
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = bullet_spawn.global_position
	bullet.set("direction", Vector2.RIGHT.rotated(rotation - sprite_rotation_offset))

	if shoot_sfx:
		shoot_sfx.volume_db = -8.0
		shoot_sfx.pitch_scale = randf_range(1.0, 1.08)
		shoot_sfx.play()

func _on_flame_sprite_animation_finished() -> void:
	if flame_sprite.animation == "start":
		flame_sprite.play("move" if thrusting else "stop")

		if thrusting and thrust_sfx and not thrust_sfx.playing:
			thrust_sfx.play()

	elif flame_sprite.animation == "stop":
		flame_sprite.play("start" if thrusting else "off")

		if not thrusting and thrust_sfx and thrust_sfx.playing:
			thrust_sfx.stop()

func _on_hyper_explosion_animation_finished() -> void:
	disable_explosion_hitbox()

	if hyper_manager.is_hyper_active():
		FormManager.set_form(FormManager.FormState.ORIGIN)
	else:
		FormManager.set_form(FormManager.FormState.ALTER)

func update_hyper_visuals() -> void:
	var s: float = hyper_manager.get_rocket_visual_scale()
	var scale_vec := Vector2.ONE * s
	var scaled_offset: Vector2 = hyper_manager.get_scaled_extension_offset()

	body_sprite.scale = scale_vec
	flame_sprite.scale = scale_vec
	hyper_extension.scale = scale_vec

	if hyper_manager.is_hyper_transitioning():
		hyper_explosion.scale = scale_vec * 4.0

	if hyper_manager.is_hyper_active():
		flame_sprite.position = base_flame_position + scaled_offset
		hyper_extension.position = base_extension_position + scaled_offset
	else:
		flame_sprite.position = base_flame_position
		hyper_extension.position = base_extension_position

func update_explosion_hitbox_state() -> void:
	var should_enable := hyper_explosion.visible and hyper_explosion.is_playing()

	if should_enable and not explosion_hitbox_enabled:
		enable_explosion_hitbox()
	elif not should_enable and explosion_hitbox_enabled:
		disable_explosion_hitbox()

func enable_explosion_hitbox() -> void:
	explosion_hitbox_enabled = true
	explosion_hitbox.set_deferred("monitoring", true)
	explosion_hitbox.set_deferred("monitorable", true)
	explosion_hitbox_shape.set_deferred("disabled", false)

func disable_explosion_hitbox() -> void:
	explosion_hitbox_enabled = false
	explosion_hitbox.set_deferred("monitoring", false)
	explosion_hitbox.set_deferred("monitorable", false)
	explosion_hitbox_shape.set_deferred("disabled", true)

func update_hyper_sfx() -> void:
	var charging_now := hyper_manager.get_hyper_charge_ratio() > 0.01 and not hyper_manager.is_hyper_transitioning()
	var transitioning_now := hyper_manager.is_hyper_transitioning()
	var active_now := hyper_manager.is_hyper_active()

	if charging_now and not was_charging:
		if hyper_charge_sfx:
			hyper_charge_sfx.play()

	if Input.is_action_just_released("hyper_charge") and was_charging:
		if hyper_charge_sfx and hyper_charge_sfx.playing:
			hyper_charge_sfx.stop()

		if not transitioning_now:
			if hyper_off_sfx:
				hyper_off_sfx.play()

	was_charging = charging_now
	was_hyper_transitioning = transitioning_now
	was_hyper_active = active_now

func stop_all_engine_sfx() -> void:
	if thrust_sfx and thrust_sfx.playing:
		thrust_sfx.stop()

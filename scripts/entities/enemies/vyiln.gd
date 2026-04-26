extends CharacterBody2D
class_name Enemy

@export var body_animation: String = "en1"
@export var eye_animation: String = "idle"
@export var limb_animation: String = "en1"

@export var enemy_type: String = "type_1"

@export var limb_count: int = 4
@export var limb_radius: float = 12.0
@export var limb_pulse_amount: float = 7.0
@export var limb_pulse_speed: float = 5.0
@export var limb_attack_spin_speed: float = 18.0
@export var limb_idle_spin_speed: float = 0.0

@export var move_speed_min: float = 90.0
@export var move_speed_max: float = 180.0
@export var acceleration: float = 260.0
@export var drag: float = 110.0

@export var avoid_player_radius: float = 120.0
@export var float_amplitude: float = 52.0
@export var float_frequency_min: float = 0.9
@export var float_frequency_max: float = 1.7
@export var ring_snap_strength: float = 2.5
@export var orbit_bias_strength: float = 0.55

@export var dash_turn_strength: float = 8.0
@export var enemy_separation_radius: float = 70.0
@export var enemy_separation_strength: float = 260.0

@export var eye_orbit_radius: float = 3.0
@export var eye_orbit_speed: float = 2.4
@export var eye_alarm_enter_duration: float = 0.14
@export var eye_alarm_spin_duration: float = 0.18
@export var eye_alarm_exit_duration: float = 0.16
@export var eye_alarm_turns: float = 2.0

@export var dash_speed_multiplier: float = 2.8
@export var retreat_speed_multiplier: float = 1.6
@export var retreat_duration: float = 0.42
@export var post_hit_retarget_delay: float = 0.25

@export var max_health: int = 3

@onready var body_origin: AnimatedSprite2D = $BodyOrigin
@onready var body_alter: AnimatedSprite2D = $BodyAlter
@onready var eye_origin: AnimatedSprite2D = $EyeOrigin
@onready var eye_alter: AnimatedSprite2D = $EyeAlter
@onready var limb_origin_template: AnimatedSprite2D = $LimbsOrigin
@onready var limb_alter_template: AnimatedSprite2D = $LimbsAlter
@onready var limb_root: Node2D = $LimbRoot

var game_stats: GameStats = null

enum ActionState {
	HOVER,
	PREPARE_DASH,
	DASH,
	RETREAT
}

enum EyeAlarmState {
	NONE,
	ENTER,
	SPIN,
	EXIT
}

var game_ref: Node = null
var rocket_ref: Node = null

var world_position: Vector2 = Vector2.ZERO
var move_velocity: Vector2 = Vector2.ZERO

var current_target: Node2D = null
var previous_target: Node2D = null
var targeting_player: bool = true

var move_speed: float = 120.0
var retarget_timer: float = 0.0

var float_phase: float = 0.0
var float_frequency: float = 1.2
var float_sign: float = 1.0

var eye_phase: float = 0.0
var eye_alarm_state: int = EyeAlarmState.NONE
var eye_alarm_timer: float = 0.0
var base_eye_origin_pos: Vector2
var base_eye_alter_pos: Vector2

var limbs: Array[Dictionary] = []
var alive_limb_count: int = 4
var limb_angle_offset: float = 0.0
var limb_time: float = 0.0

var health: int = 1
var dash_direction: Vector2 = Vector2.ZERO
var retreat_timer: float = 0.0
var action_state: int = ActionState.HOVER


func _ready() -> void:
	base_eye_origin_pos = eye_origin.position
	base_eye_alter_pos = eye_alter.position
	health = max_health

	_setup_animations()
	_setup_limbs()
	_apply_form_visuals(FormManager.current_form)

	if not FormManager.form_changed.is_connected(_on_form_changed):
		FormManager.form_changed.connect(_on_form_changed)


func setup_vyiln(game_node: Node, rocket_node: Node, spawn_world_pos: Vector2, difficulty: float) -> void:
	game_ref = game_node
	rocket_ref = rocket_node
	world_position = spawn_world_pos
	position = world_position

	move_speed = lerp(move_speed_min, move_speed_max, difficulty)

	float_frequency = randf_range(float_frequency_min, float_frequency_max)
	float_phase = randf() * TAU
	float_sign = -1.0 if randf() < 0.5 else 1.0

	eye_phase = randf() * TAU

	_pick_player_target(true)


func _physics_process(delta: float) -> void:
	_update_targeting()
	_update_action_state(delta)
	_update_movement(delta)
	_update_eye_motion(delta)
	_update_limbs(delta)

	position = world_position


func _process(_delta: float) -> void:
	_sync_sprite(body_origin, body_alter)
	_sync_sprite(eye_origin, eye_alter)


func _exit_tree() -> void:
	if FormManager.form_changed.is_connected(_on_form_changed):
		FormManager.form_changed.disconnect(_on_form_changed)


func take_hit(damage: int = 1) -> void:
	health -= damage
	_remove_one_limb()

	if game_stats:
		game_stats.add_score(game_stats.score_limb_break)

	if health <= 0 or alive_limb_count <= 0:
		if game_stats:
			game_stats.enemy_killed(enemy_type)

		queue_free()
		return

	_start_retreat()


func _setup_animations() -> void:
	_play_if_exists(body_origin, body_animation)
	_play_if_exists(body_alter, body_animation)
	_play_if_exists(eye_origin, eye_animation)
	_play_if_exists(eye_alter, eye_animation)


func _play_if_exists(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		return

	var anims := sprite.sprite_frames.get_animation_names()
	if anims.size() > 0:
		sprite.play(anims[0])
	else:
		push_warning(sprite.name + " has no animations.")


func _setup_limbs() -> void:
	limbs.clear()
	alive_limb_count = limb_count

	limb_origin_template.visible = false
	limb_alter_template.visible = false

	for child in limb_root.get_children():
		child.queue_free()

	for i in range(limb_count):
		var origin := limb_origin_template.duplicate() as AnimatedSprite2D
		var alter := limb_alter_template.duplicate() as AnimatedSprite2D

		origin.name = "LimbOrigin_%d" % i
		alter.name = "LimbAlter_%d" % i

		origin.visible = true
		alter.visible = true

		origin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		alter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		limb_root.add_child(origin)
		limb_root.add_child(alter)

		_play_if_exists(origin, limb_animation)
		_play_if_exists(alter, limb_animation)

		limbs.append({
			"origin": origin,
			"alter": alter,
			"alive": true,
			"base_angle": TAU * float(i) / float(limb_count),
			"phase": TAU * float(i) / float(limb_count)
		})


func _apply_form_visuals(form: int) -> void:
	var show_origin := form == FormManager.FormState.ORIGIN
	var show_alter := form == FormManager.FormState.ALTER

	body_origin.visible = show_origin
	body_alter.visible = show_alter
	eye_origin.visible = show_origin
	eye_alter.visible = show_alter

	for limb in limbs:
		var alive: bool = limb.get("alive", true)
		var origin: AnimatedSprite2D = limb.get("origin", null)
		var alter: AnimatedSprite2D = limb.get("alter", null)

		if origin:
			origin.visible = show_origin and alive

		if alter:
			alter.visible = show_alter and alive


func _on_form_changed(new_form: int) -> void:
	_apply_form_visuals(new_form)


func _sync_sprite(source: AnimatedSprite2D, target: AnimatedSprite2D) -> void:
	if source == null or target == null:
		return

	target.animation = source.animation
	target.frame = source.frame
	target.frame_progress = source.frame_progress


func _update_targeting() -> void:
	if rocket_ref == null:
		return

	if current_target != rocket_ref:
		_pick_player_target(true)

	if action_state == ActionState.HOVER:
		action_state = ActionState.PREPARE_DASH


func _pick_player_target(force_alarm: bool) -> void:
	if rocket_ref == null:
		return

	previous_target = current_target
	current_target = rocket_ref as Node2D
	targeting_player = true

	if force_alarm or current_target != previous_target:
		_trigger_eye_alarm()


func _update_action_state(delta: float) -> void:
	match action_state:
		ActionState.HOVER:
			pass

		ActionState.PREPARE_DASH:
			if eye_alarm_state == EyeAlarmState.NONE:
				_start_dash()

		ActionState.DASH:
			var target_world := _get_player_world_position()
			target_world += _get_player_velocity() * 0.12

			var to_target := target_world - world_position
			var desired_dir := to_target.normalized()

			if desired_dir == Vector2.ZERO:
				desired_dir = dash_direction

			dash_direction = dash_direction.lerp(
				desired_dir,
				min(dash_turn_strength * delta, 1.0)
			).normalized()

			var desired_velocity := dash_direction * move_speed * dash_speed_multiplier
			move_velocity = move_velocity.move_toward(
				desired_velocity,
				acceleration * 3.0 * delta
			)

			move_velocity += _get_enemy_separation_force() * delta

		ActionState.RETREAT:
			retreat_timer += delta

			if retreat_timer >= retreat_duration:
				retarget_timer = post_hit_retarget_delay
				_pick_player_target(true)
				action_state = ActionState.PREPARE_DASH


func _start_dash() -> void:
	var target_world := _get_player_world_position()
	target_world += _get_player_velocity() * 0.22

	dash_direction = (target_world - world_position).normalized()

	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT

	action_state = ActionState.DASH


func _start_retreat() -> void:
	retreat_timer = 0.0
	action_state = ActionState.RETREAT


func _update_movement(delta: float) -> void:
	match action_state:
		ActionState.HOVER, ActionState.PREPARE_DASH:
			_update_hover_movement(delta)

		ActionState.DASH:
			var desired_velocity := dash_direction * move_speed * dash_speed_multiplier
			move_velocity = move_velocity.move_toward(
				desired_velocity,
				acceleration * 2.1 * delta
			)
			world_position += move_velocity * delta

		ActionState.RETREAT:
			var away_dir := (world_position - _get_player_world_position()).normalized()

			if away_dir == Vector2.ZERO:
				away_dir = Vector2.RIGHT

			var tangent := Vector2(-away_dir.y, away_dir.x) * float_sign
			var retreat_dir := (away_dir + tangent * 0.35).normalized()
			var desired_velocity := retreat_dir * move_speed * retreat_speed_multiplier

			move_velocity = move_velocity.move_toward(
				desired_velocity,
				acceleration * 1.7 * delta
			)

			world_position += move_velocity * delta


func _update_hover_movement(delta: float) -> void:
	var target_world := _get_player_world_position()
	var to_target := target_world - world_position
	var dist := to_target.length()

	if dist <= 0.001:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, drag * delta)
		return

	var dir := to_target / dist
	var tangent := Vector2(-dir.y, dir.x) * float_sign

	float_phase += delta * float_frequency * TAU

	var stop_radius := avoid_player_radius
	var ring_error := dist - stop_radius

	var ring_center := target_world - dir * stop_radius
	var wobble_offset := tangent * sin(float_phase) * float_amplitude
	var desired_point := ring_center + wobble_offset

	var to_desired := desired_point - world_position
	var desired_dir := to_desired.normalized() if to_desired.length() > 0.001 else Vector2.ZERO

	var tangential_flow := tangent * orbit_bias_strength
	var radial_correction := dir * ring_error * ring_snap_strength * 0.01

	var blended_dir := (desired_dir + tangential_flow + radial_correction).normalized()

	if blended_dir == Vector2.ZERO:
		blended_dir = dir

	var desired_speed := move_speed

	if abs(ring_error) < 120.0:
		desired_speed *= clamp(abs(ring_error) / 120.0, 0.22, 1.0)

	var desired_velocity := blended_dir * desired_speed

	if dist < stop_radius * 0.88:
		desired_velocity = -dir * move_speed * 0.95

	move_velocity = move_velocity.move_toward(desired_velocity, acceleration * delta)
	move_velocity = move_velocity.move_toward(Vector2.ZERO, drag * 0.08 * delta)

	world_position += move_velocity * delta


func _update_eye_motion(delta: float) -> void:
	eye_phase += delta * eye_orbit_speed

	var orbit_offset := Vector2(cos(eye_phase), sin(eye_phase)) * eye_orbit_radius
	var final_offset := orbit_offset
	var final_rotation := 0.0

	match eye_alarm_state:
		EyeAlarmState.NONE:
			pass

		EyeAlarmState.ENTER:
			eye_alarm_timer += delta
			var t_enter : float = clamp(eye_alarm_timer / eye_alarm_enter_duration, 0.0, 1.0)
			final_offset = orbit_offset.lerp(Vector2.ZERO, _smoothstep(t_enter))

			if t_enter >= 1.0:
				eye_alarm_state = EyeAlarmState.SPIN
				eye_alarm_timer = 0.0

		EyeAlarmState.SPIN:
			eye_alarm_timer += delta
			var t_spin : float = clamp(eye_alarm_timer / eye_alarm_spin_duration, 0.0, 1.0)

			final_offset = Vector2.ZERO
			final_rotation = TAU * eye_alarm_turns * t_spin

			if t_spin >= 1.0:
				eye_alarm_state = EyeAlarmState.EXIT
				eye_alarm_timer = 0.0

		EyeAlarmState.EXIT:
			eye_alarm_timer += delta
			var t_exit : float = clamp(eye_alarm_timer / eye_alarm_exit_duration, 0.0, 1.0)
			final_offset = Vector2.ZERO.lerp(orbit_offset, _smoothstep(t_exit))

			if t_exit >= 1.0:
				eye_alarm_state = EyeAlarmState.NONE
				eye_alarm_timer = 0.0

	eye_origin.position = base_eye_origin_pos + final_offset
	eye_alter.position = base_eye_alter_pos + final_offset

	eye_origin.rotation = final_rotation
	eye_alter.rotation = final_rotation


func _update_limbs(delta: float) -> void:
	limb_time += delta

	var attacking := action_state == ActionState.PREPARE_DASH or action_state == ActionState.DASH

	if attacking:
		limb_angle_offset += limb_attack_spin_speed * delta
	else:
		limb_angle_offset += limb_idle_spin_speed * delta

	for i in range(limbs.size()):
		var limb := limbs[i]

		if not limb.get("alive", true):
			continue

		var origin: AnimatedSprite2D = limb.get("origin", null)
		var alter: AnimatedSprite2D = limb.get("alter", null)

		var base_angle: float = limb.get("base_angle", 0.0)
		var phase: float = limb.get("phase", 0.0)

		var angle := base_angle + limb_angle_offset
		var pulse := sin(limb_time * limb_pulse_speed + phase) * limb_pulse_amount
		var offset := Vector2(cos(angle), sin(angle)) * (limb_radius + pulse)
		var limb_rotation := angle + PI / 2.0

		if origin:
			origin.position = offset
			origin.rotation = limb_rotation

		if alter:
			alter.position = offset
			alter.rotation = limb_rotation


func _remove_one_limb() -> void:
	for i in range(limbs.size() - 1, -1, -1):
		var limb := limbs[i]

		if limb.get("alive", true):
			limb["alive"] = false
			alive_limb_count -= 1

			var origin: AnimatedSprite2D = limb.get("origin", null)
			var alter: AnimatedSprite2D = limb.get("alter", null)

			if origin:
				origin.visible = false

			if alter:
				alter.visible = false

			limbs[i] = limb
			return


func _get_player_world_position() -> Vector2:
	if rocket_ref == null:
		return world_position

	var pos = rocket_ref.get("world_position")

	if pos is Vector2:
		return pos

	return world_position


func _get_player_velocity() -> Vector2:
	if rocket_ref == null:
		return Vector2.ZERO

	var v = rocket_ref.get("velocity")

	if v is Vector2:
		return v

	return Vector2.ZERO


func _trigger_eye_alarm() -> void:
	eye_alarm_state = EyeAlarmState.ENTER
	eye_alarm_timer = 0.0


func _smoothstep(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_enemy_separation_force() -> Vector2:
	if game_ref == null:
		return Vector2.ZERO

	var enemies = game_ref.get("enemy_instances")

	if not (enemies is Array):
		return Vector2.ZERO

	var force := Vector2.ZERO

	for other in enemies:
		if other == self:
			continue

		if other == null or not is_instance_valid(other):
			continue

		var other_pos = other.get("world_position")

		if not (other_pos is Vector2):
			continue

		var away: Vector2 = world_position - other_pos
		var dist := away.length()

		if dist <= 0.001 or dist > enemy_separation_radius:
			continue

		var strength := 1.0 - dist / enemy_separation_radius
		force += away.normalized() * strength * enemy_separation_strength

	return force

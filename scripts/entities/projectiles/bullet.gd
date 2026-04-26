extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 400.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = 99
	add_to_group("player_bullet")

	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

	_apply_form_animation()

	FormManager.form_changed.connect(_on_form_changed)

	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

	if direction != Vector2.ZERO:
		rotation = direction.angle() + deg_to_rad(90)


func _exit_tree() -> void:
	if FormManager.form_changed.is_connected(_on_form_changed):
		FormManager.form_changed.disconnect(_on_form_changed)


func _apply_form_animation() -> void:
	if animated_sprite.sprite_frames == null:
		return

	var saved_frame := animated_sprite.frame

	if FormManager.is_alter():
		if animated_sprite.sprite_frames.has_animation("alter"):
			animated_sprite.play("alter")
	else:
		if animated_sprite.sprite_frames.has_animation("origin"):
			animated_sprite.play("origin")

	var frame_count := animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	if frame_count > 0:
		animated_sprite.frame = clamp(saved_frame, 0, frame_count - 1)


func _on_form_changed(_new_form: int) -> void:
	_apply_form_animation()


func _on_hit(_thing) -> void:
	queue_free()

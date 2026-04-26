extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	_update_resolution()

func _process(_delta: float) -> void:
	_update_resolution()

func _update_resolution() -> void:
	if rect.material:
		rect.material.set_shader_parameter("resolution", get_viewport().get_visible_rect().size)

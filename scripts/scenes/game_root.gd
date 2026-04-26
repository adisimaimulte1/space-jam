extends Node2D

@onready var scene_container = $SceneContainer

var current_scene: Node = null

func _ready():
	switch_scene(preload("res://scenes/space/MenuScene.tscn"))

func switch_scene(scene_resource: PackedScene):
	if current_scene:
		current_scene.queue_free()

	current_scene = scene_resource.instantiate()
	scene_container.add_child(current_scene)

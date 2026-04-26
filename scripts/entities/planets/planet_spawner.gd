extends RefCounted
class_name PlanetSpawner

static func spawn_system(owner: Node, holder: Node2D, scenes: Dictionary, type_name: String, palette: Array[Color], seed_value: int, cfg: Dictionary) -> Dictionary:
	var current_planet: Control = scenes[type_name].instantiate()
	holder.add_child(current_planet)

	make_instance_resources_unique(current_planet)
	normalize_control_anchors(current_planet)
	apply_planet_properties(current_planet, palette, seed_value, cfg)

	var final_scale: Vector2 = await finalize_holder_scale(owner, holder, cfg)
	add_debug_bounds(holder)

	return {
		"current_planet": current_planet,
		"final_scale": final_scale
	}

static func normalize_control_anchors(root: Node) -> void:
	if root is Control:
		var c: Control = root
		c.anchor_left = 0.0
		c.anchor_top = 0.0
		c.anchor_right = 0.0
		c.anchor_bottom = 0.0

	for child in root.get_children():
		normalize_control_anchors(child)

static func apply_planet_properties(planet: Control, palette: Array[Color], seed_value: int, cfg: Dictionary) -> void:
	var pixel_count: int = randi_range(
		int(cfg.get("pixels_min", 60)),
		int(cfg.get("pixels_max", 80))
	)

	if planet.has_method("set_pixels"):
		planet.set_pixels(pixel_count)

	if planet.has_method("set_seed"):
		planet.set_seed(seed_value)

	if planet.has_method("set_light"):
		var light_min: float = cfg.get("light_min", 0.4)
		var light_max: float = cfg.get("light_max", 0.6)
		planet.set_light(Vector2(
			randf_range(light_min, light_max),
			randf_range(light_min, light_max)
		))

	if planet.has_method("set_rotates"):
		planet.set_rotates(randf() if cfg.get("rotates", true) else 0.0)

	if planet.has_method("set_colors"):
		planet.set_colors(palette)

static func finalize_holder_scale(owner: Node, holder: Node2D, cfg: Dictionary) -> Vector2:
	await owner.get_tree().process_frame

	var bounds: Rect2 = get_holder_visual_bounds(holder)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_error("No visual Control bounds found for planet system.")
		return Vector2.ONE

	var center_offset: Vector2 = bounds.position + bounds.size * 0.5

	for child in holder.get_children():
		if child is Control and child.name != "DebugBounds":
			(child as Control).position -= center_offset

	bounds = get_holder_visual_bounds(holder)

	var base_size: float = max(bounds.size.x, bounds.size.y)
	if base_size <= 0.0:
		base_size = 100.0

	var min_size: float = cfg.get("min_size", PlanetData.DEFAULT_MIN_SIZE)
	var max_size: float = cfg.get("max_size", PlanetData.DEFAULT_MAX_SIZE)
	var target_size: float = randf_range(min_size, max_size)

	var final_scale_value: float = target_size / base_size
	var final_scale: Vector2 = Vector2.ONE * final_scale_value
	holder.scale = final_scale

	return final_scale

static func make_instance_resources_unique(root: Node) -> void:
	if root is CanvasItem:
		var item: CanvasItem = root
		if item.material != null:
			item.material = item.material.duplicate(true)

	for child in root.get_children():
		make_instance_resources_unique(child)

static func get_holder_visual_bounds(holder: Node2D) -> Rect2:
	var result := _collect_bounds_recursive(holder, Vector2.ZERO, false, Rect2())
	return result["rect"]

static func _collect_bounds_recursive(node: Node, accumulated_offset: Vector2, has_rect: bool, merged_rect: Rect2) -> Dictionary:
	var local_has_rect: bool = has_rect
	var local_merged_rect: Rect2 = merged_rect
	var next_offset: Vector2 = accumulated_offset

	if node is Control and node.name != "DebugBounds":
		var control: Control = node
		next_offset += control.position

		if control.size.x > 0.0 and control.size.y > 0.0:
			var rect := Rect2(next_offset, control.size)
			if local_has_rect:
				local_merged_rect = local_merged_rect.merge(rect)
			else:
				local_merged_rect = rect
				local_has_rect = true

	for child in node.get_children():
		var child_result: Dictionary = _collect_bounds_recursive(child, next_offset, local_has_rect, local_merged_rect)
		local_has_rect = child_result["has_rect"]
		local_merged_rect = child_result["rect"]

	return {
		"has_rect": local_has_rect,
		"rect": local_merged_rect
	}

static func add_debug_bounds(holder: Node2D) -> void:
	var old_rect := holder.get_node_or_null("DebugBounds")
	if old_rect != null:
		old_rect.queue_free()

	var bounds: Rect2 = get_holder_visual_bounds(holder)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var rect := ReferenceRect.new()
	rect.name = "DebugBounds"
	rect.editor_only = false
	rect.visible = false
	rect.border_color = Color(1.0, 0.1, 0.1, 1.0)
	rect.border_width = 3.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 0.0
	rect.anchor_bottom = 0.0
	rect.position = bounds.position
	rect.size = bounds.size

	holder.add_child(rect)

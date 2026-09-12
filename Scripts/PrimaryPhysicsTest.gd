extends Node2D

@export var segment_count: int = 24
@export var segment_length: float = 16.0
@export var gravity: Vector2 = Vector2(0, 980)
@export var constraint_iterations: int = 8
@export_range(0.01, 100.0, 0.01) var end_mass: float = 1.0
@export var end_force: Vector2 = Vector2.ZERO
@export_range(0.0, 1000000.0, 100.0) var youngs_modulus: float = 100000.0
@export var lower_end_position: Vector2 = Vector2(0, 384)
@export var mouse_pick_radius: float = 24.0
@export_range(0.000001, 1.0, 0.000001) var cross_sectional_area: float = 0.0001
@export_range(1.0, 1000000000.0, 1000.0) var breaking_stress: float = 500000.0

var points: Array[Vector2] = []
var previous_points: Array[Vector2] = []
var broken_segments: Array[bool] = []
var dragged_endpoint: int = -1
var controls_panel: VBoxContainer

const REFERENCE_YOUNGS_MODULUS: float = 100000.0

func _ready() -> void:
	_rebuild_rope()
	_build_controls()
	queue_redraw()

func _rebuild_rope() -> void:
	points.clear()
	previous_points.clear()
	broken_segments.clear()
	for index in segment_count + 1:
		var point := Vector2(0, index * segment_length)
		points.append(point)
		previous_points.append(point)
		if index < segment_count:
			broken_segments.append(false)
	points[points.size() - 1] = lower_end_position
	previous_points[previous_points.size() - 1] = lower_end_position

func _process(delta: float) -> void:
	var safe_end_mass: float = maxf(end_mass, 0.01)
	var constraint_strength: float = clampf(youngs_modulus / REFERENCE_YOUNGS_MODULUS, 0.0, 1.0)
	if dragged_endpoint != -1:
		var mouse_position: Vector2 = to_local(get_global_mouse_position())
		points[dragged_endpoint] = mouse_position
		previous_points[dragged_endpoint] = mouse_position
	for index in range(1, points.size()):
		if index == dragged_endpoint:
			continue
		var frame_displacement: Vector2 = points[index] - previous_points[index]
		previous_points[index] = points[index]
		var acceleration: Vector2 = gravity
		if index == points.size() - 1:
			acceleration += end_force / safe_end_mass
		points[index] += frame_displacement + acceleration * delta * delta

	for iteration in constraint_iterations:
		for index in range(points.size() - 1):
			if broken_segments[index]:
				continue
			var first_point: Vector2 = points[index]
			var second_point: Vector2 = points[index + 1]
			var direction: Vector2 = second_point - first_point
			var distance: float = direction.length()
			if distance == 0.0:
				continue

			var correction: Vector2 = direction * ((distance - segment_length) / distance)
			var first_inverse_mass: float = 0.0 if index == 0 else 1.0
			var second_inverse_mass: float = 1.0
			if index + 1 == points.size() - 1:
				second_inverse_mass = 1.0 / safe_end_mass
			var inverse_mass_sum: float = first_inverse_mass + second_inverse_mass
			points[index] += correction * first_inverse_mass / inverse_mass_sum * constraint_strength
			points[index + 1] -= correction * second_inverse_mass / inverse_mass_sum * constraint_strength

	_update_breaks_and_measurements()
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return

	draw_circle(points[0], 7.0, Color("e8b04a"))
	for index in range(points.size() - 1):
		var segment_color: Color = Color("d94f4f") if broken_segments[index] else Color("f4eee2")
		draw_line(points[index], points[index + 1], segment_color, 4.0, true)
		draw_circle(points[index + 1], 4.0, Color("d6674d"))

	var measurements: Dictionary = _get_measurements()
	var font: Font = ThemeDB.fallback_font
	var text_position := Vector2(16, 28)
	draw_string(font, text_position, "Tension: %.2f N" % measurements.tension, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, text_position + Vector2(0, 20), "Stress: %.2f Pa" % measurements.stress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, text_position + Vector2(0, 40), "Strain: %.5f" % measurements.strain, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, text_position + Vector2(0, 60), "Breaking: %.2f N / %.2f Pa / %.5f strain" % [measurements.breaking_tension, breaking_stress, measurements.breaking_strain], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2c14e"))

func _get_measurements() -> Dictionary:
	var maximum_tension: float = 0.0
	var maximum_stress: float = 0.0
	var maximum_strain: float = 0.0
	for index in range(points.size() - 1):
		var strain: float = (points[index].distance_to(points[index + 1]) - segment_length) / segment_length
		var stress: float = youngs_modulus * strain
		var tension: float = maxf(stress, 0.0) * cross_sectional_area
		maximum_strain = maxf(maximum_strain, strain)
		maximum_stress = maxf(maximum_stress, stress)
		maximum_tension = maxf(maximum_tension, tension)
	return {
		"tension": maximum_tension,
		"stress": maximum_stress,
		"strain": maximum_strain,
		"breaking_tension": breaking_stress * cross_sectional_area,
		"breaking_strain": breaking_stress / maxf(youngs_modulus, 0.000001)
	}

func _update_breaks_and_measurements() -> void:
	for index in range(points.size() - 1):
		if broken_segments[index]:
			continue
		var strain: float = (points[index].distance_to(points[index + 1]) - segment_length) / segment_length
		var stress: float = youngs_modulus * strain
		if stress >= breaking_stress:
			broken_segments[index] = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_position: Vector2 = to_local(get_global_mouse_position())
			var nearest_endpoint: int = 0 if mouse_position.distance_to(points[0]) < mouse_position.distance_to(points[points.size() - 1]) else points.size() - 1
			if mouse_position.distance_to(points[nearest_endpoint]) <= mouse_pick_radius:
				dragged_endpoint = nearest_endpoint
		else:
			dragged_endpoint = -1

func _build_controls() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(320, 560)
	canvas_layer.add_child(panel)
	controls_panel = VBoxContainer.new()
	controls_panel.add_theme_constant_override("separation", 2)
	panel.add_child(controls_panel)

	var title := Label.new()
	title.text = "ROPE CONTROLS"
	controls_panel.add_child(title)
	_add_slider("Segments", 4.0, 80.0, 1.0, segment_count, _set_segment_count)
	_add_slider("Segment length", 4.0, 40.0, 0.5, segment_length, _set_segment_length)
	_add_slider("Gravity X", -2000.0, 2000.0, 10.0, gravity.x, _set_gravity_x)
	_add_slider("Gravity Y", -2000.0, 2000.0, 10.0, gravity.y, _set_gravity_y)
	_add_slider("Constraint iterations", 1.0, 20.0, 1.0, constraint_iterations, _set_constraint_iterations)
	_add_slider("End mass", 0.01, 100.0, 0.01, end_mass, _set_end_mass)
	_add_slider("End force X", -5000.0, 5000.0, 10.0, end_force.x, _set_end_force_x)
	_add_slider("End force Y", -5000.0, 5000.0, 10.0, end_force.y, _set_end_force_y)
	_add_slider("Young's modulus", 0.0, 1000000.0, 1000.0, youngs_modulus, _set_youngs_modulus)
	_add_slider("Lower position X", -600.0, 600.0, 1.0, lower_end_position.x, _set_lower_position_x)
	_add_slider("Lower position Y", -600.0, 900.0, 1.0, lower_end_position.y, _set_lower_position_y)
	_add_slider("Mouse pick radius", 4.0, 80.0, 1.0, mouse_pick_radius, _set_mouse_pick_radius)
	_add_slider("Cross-sectional area", 0.000001, 1.0, 0.000001, cross_sectional_area, _set_cross_sectional_area)
	_add_slider("Breaking stress", 1000.0, 1000000000.0, 1000.0, breaking_stress, _set_breaking_stress)

func _add_slider(label_text: String, minimum: float, maximum: float, step: float, initial_value: float, setter: Callable) -> void:
	var label := Label.new()
	var slider := HSlider.new()
	var value_label := Label.new()
	var row := HBoxContainer.new()
	label.text = label_text
	label.custom_minimum_size.x = 112
	label.add_theme_font_size_override("font_size", 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 68
	value_label.add_theme_font_size_override("font_size", 11)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 16
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _format_control_value(value, step)
		setter.call(value)
	)
	value_label.text = _format_control_value(initial_value, step)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	controls_panel.add_child(row)

func _format_control_value(value: float, step: float) -> String:
	if step < 0.001:
		return "%.6f" % value
	if step < 1.0:
		return "%.2f" % value
	return "%.0f" % value

func _set_segment_count(value: float) -> void:
	segment_count = int(value)
	_rebuild_rope()

func _set_segment_length(value: float) -> void:
	segment_length = value

func _set_gravity_x(value: float) -> void:
	gravity.x = value

func _set_gravity_y(value: float) -> void:
	gravity.y = value

func _set_constraint_iterations(value: float) -> void:
	constraint_iterations = int(value)

func _set_end_mass(value: float) -> void:
	end_mass = value

func _set_end_force_x(value: float) -> void:
	end_force.x = value

func _set_end_force_y(value: float) -> void:
	end_force.y = value

func _set_youngs_modulus(value: float) -> void:
	youngs_modulus = value

func _set_lower_position_x(value: float) -> void:
	lower_end_position.x = value
	if dragged_endpoint == -1 and points.size() > 1:
		points[points.size() - 1].x = value
		previous_points[previous_points.size() - 1].x = value

func _set_lower_position_y(value: float) -> void:
	lower_end_position.y = value
	if dragged_endpoint == -1 and points.size() > 1:
		points[points.size() - 1].y = value
		previous_points[previous_points.size() - 1].y = value

func _set_mouse_pick_radius(value: float) -> void:
	mouse_pick_radius = value

func _set_cross_sectional_area(value: float) -> void:
	cross_sectional_area = value

func _set_breaking_stress(value: float) -> void:
	breaking_stress = value

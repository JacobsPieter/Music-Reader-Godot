extends Control
## Freehand drawing canvas with preset and custom colour selection.

const BUTTON_STATES_USING_NORMAL := ["normal", "focus", "hover"]

var preset_colours: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.002, 0.254, 0.919, 1.0),
	Color(0.643, 0.0, 0.091, 1.0),
	Color(0.173, 0.345, 0.116, 1.0)]

var current_colour := preset_colours[0]

var current_stroke := Stroke.new()
var strokes: Array[Stroke] = [current_stroke]

@onready var preset_buttons: Array = [%ColourButton1, %ColourButton2, %ColourButton3, %ColourButton4,]
@onready var custom_pickers: Array = [%ColorPickerButton1, %ColorPickerButton2]
@onready var custom_overlays: Array = [%CustomColourButtonOverlay1, %CustomColourButtonOverlay2]


## The base class to use for the annotations. All hand-drawn lines need to be a subclass of this.
class Stroke:
	var colour := Color()
	var width: float
	var points := PackedVector2Array()
	var pressures := PackedFloat64Array()
	var tilts := PackedVector2Array()

	func add_point(point: Vector2, pressure := 1.0, tilt := Vector2.ZERO) -> void:
		points.append(point)
		pressures.append(pressure)
		tilts.append(tilt)

	## Compresses the points to a much more manageable size without losing too much detail.
	## Run before last compression.
	func compress_line() -> void:
		var indices := RamerDouglasPeucker.calculate_indices(points, 0.1)
		points = RamerDouglasPeucker.select_points(points, indices)
		pressures = PackedFloat64Array(RamerDouglasPeucker.filter_by_indices(pressures, indices))
		tilts = PackedVector2Array(RamerDouglasPeucker.filter_by_indices(tilts, indices))

	func compress() -> void:
		pass

	func decompress() -> void:
		pass


func _ready() -> void:
	for picker in custom_pickers:
		picker.color_changed.connect(_on_custom_colour_changed.unbind(1))
		picker.popup_closed.connect(start_new_stroke)
	update_colour_button_colours()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		update_current_colour()
		current_stroke.colour = current_colour
		current_stroke.width = %BrushSizes.value
		current_stroke.add_point(
			event.position,
			event.pressure if event.pressure != 0.0 else 1.0,
			event.tilt,
		)
		queue_redraw()
	elif event is InputEventScreenTouch and event.is_pressed():
		start_new_stroke()


func _draw() -> void:
	for stroke in strokes:
		if stroke.points.size() < 2:
			continue
		draw_polyline_colors(stroke.points, PackedColorArray([stroke.colour]), stroke.width)


## Finishes the current stroke and begins a fresh one.
func start_new_stroke() -> void:
	current_stroke.compress_line()
	current_stroke = Stroke.new()
	strokes.append(current_stroke)


func update_current_colour() -> void:
	for i in preset_buttons.size():
		if preset_buttons[i].button_pressed:
			current_colour = preset_colours[i]
			return
	for picker in custom_pickers:
		if picker.button_pressed:
			current_colour = picker.color
			return


func update_colour_button_colours() -> void:
	var base_normal: StyleBoxFancy = preset_buttons[0].get_theme_stylebox("normal")
	var base_pressed: StyleBoxFancy = preset_buttons[0].get_theme_stylebox("pressed")

	for i in preset_buttons.size():
		var button: Button = preset_buttons[i]
		var colour := preset_colours[i]
		for state in BUTTON_STATES_USING_NORMAL:
			button.add_theme_stylebox_override(state, _coloured_copy(base_normal, colour))
		button.add_theme_stylebox_override("pressed", _coloured_copy(base_pressed, colour))

	for i in custom_overlays.size():
		custom_overlays[i].add_theme_stylebox_override(
			"panel", _coloured_copy(base_normal, custom_pickers[i].color)
		)


func _coloured_copy(stylebox: StyleBoxFancy, colour: Color) -> StyleBoxFancy:
	var copy: StyleBoxFancy = stylebox.duplicate()
	copy.color = colour
	return copy


func _on_custom_colour_changed() -> void:
	update_colour_button_colours()
	update_current_colour()
	start_new_stroke()

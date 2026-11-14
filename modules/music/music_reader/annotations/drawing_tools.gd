class_name DrawingTools
extends Control
## Shared drawing tool settings: colour presets, custom colours and brush size.
##
## Exists once per screen. Every PageCanvas asks it for the current colour and width when a
## stroke starts, so changing a tool never touches strokes that are already drawn.

const BUTTON_STATES_USING_NORMAL := ["normal", "focus", "hover"]

var preset_colours: Array[Color] = [
	Color.BLACK,
	Color.BLUE,
	Color.RED,
	Color.GREEN,
]

## Brush width in page units (the same space the strokes are stored in).
var brush_width: float:
	get:
		return %BrushSizes.value

var _current_colour := preset_colours[0]

@onready var preset_buttons: Array = [
	%ColourButton1, %ColourButton2, %ColourButton3, %ColourButton4,
]
@onready var custom_pickers: Array = [%ColorPickerButton1, %ColorPickerButton2]
@onready var custom_overlays: Array = [%CustomColourButtonOverlay1, %CustomColourButtonOverlay2]
@onready var editing_settings_container = %EditingSettingsContainer
@onready var showbutton = %ShowButton
@onready var brush_size_slider = %BrushSizes

@export var canvas_parent: MusicDisplay

var drawing = false


func _ready() -> void:
	for picker in custom_pickers:
		picker.color_changed.connect(_on_custom_colour_changed.unbind(1))
	update_colour_button_colours()
	


## The colour of whichever preset or custom button is currently selected.
func get_colour() -> Color:
	_update_current_colour()
	return _current_colour


func _update_current_colour() -> void:
	for i in preset_buttons.size():
		if preset_buttons[i].button_pressed:
			_current_colour = preset_colours[i]
			return
	for picker in custom_pickers:
		if picker.button_pressed:
			_current_colour = picker.color
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


func _on_show_button_pressed() -> void:
	editing_settings_container.visible = true


func _on_edit_toggle_button_toggled(toggled_on: bool) -> void:
	canvas_parent.annotating = toggled_on
	showbutton.visible = toggled_on
	if not toggled_on:
		editing_settings_container.visible = toggled_on
		drawing = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_released():
		if not drawing and editing_settings_container.visible:
			drawing = true
			editing_settings_container.visible = false
	

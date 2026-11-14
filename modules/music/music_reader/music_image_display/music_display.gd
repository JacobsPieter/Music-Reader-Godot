class_name MusicDisplay
extends Control

@onready var rendered_first_page_display = %FirstPageDisplay
@onready var first_page_container = %FirstPageContainer
@onready var rendered_second_page_display = %SecondPageDisplay
@onready var second_page_container = %SecondPageContainer
@onready var rendered_single_page_display = %SinglePageDisplay
@onready var visibility_timer = %VisibilityTimer
@onready var splitter = %VSplitContainer

var available_space = size

var current_page: Vector2i = Vector2i(0,0)
var files: PackedStringArray
var rendered_pages: Array[ImageTexture] = []
var page_ids: PackedStringArray = []
var group_name: String = ""

## Should be true when the second part of the page gets flipped (so it is true when the top and
## bottom screen display a different page)
var page_flip: bool = false

var on_visibility_timeout: bool = false

var annotating = false

func change_displayed_page(first_page_nr: int, second_page_nr: int) -> void:
	current_page = Vector2i(first_page_nr, second_page_nr)
	if first_page_nr == second_page_nr:
		splitter.visible = false
		rendered_single_page_display.visible = true
		rendered_single_page_display.load_page(page_ids[current_page[0]], rendered_pages[current_page[0]])
		rendered_single_page_display.group_name = group_name
	else:
		splitter.visible = true
		rendered_single_page_display.visible = false
		rendered_first_page_display.load_page(page_ids[current_page[0]], rendered_pages[current_page[0]])
		rendered_first_page_display.group_name = group_name
		rendered_second_page_display.load_page(page_ids[current_page[1]], rendered_pages[current_page[1]])
		rendered_second_page_display.group_name = group_name

 

func render_music():
	rendered_pages = []
	for file in files:
		var page_image = Image.load_from_file(file)
		rendered_pages.append(ImageTexture.create_from_image(page_image))



func move_page(direction: int):
	if direction > 0:
		if current_page[1] + direction >= len(rendered_pages):
			return
		if page_flip:
			change_displayed_page(current_page[0], current_page[1] + direction)
		else:
			change_displayed_page(current_page[0] + direction, current_page[1])
	if direction < 0:
		if current_page[0] == 0:
			return
		if page_flip:
			change_displayed_page(current_page[0] + direction, current_page[1])
		else:
			change_displayed_page(current_page[0], current_page[1] + direction)
	page_flip = not page_flip





func _ready() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_released():
		if not annotating:
			if event.position.x > size.x / 2 or event.position.y > size.y / 2:
				move_page(1)
			else:
				move_page(-1)


func _on_score_selection_widget_score_selected(files_in: Array, group_name_in: String, page_ids_in: PackedStringArray) -> void:
	page_ids = page_ids_in
	files = files_in
	group_name = group_name_in
	files.sort()
	page_ids_in.sort()
	render_music()
	change_displayed_page(0,0)
	page_flip = false
	


func _on_visibility_changed() -> void:
	if is_node_ready():
		visibility_timer.start()
		on_visibility_timeout = true


func _on_visibility_timer_timeout() -> void:
	on_visibility_timeout = false


func _on_item_rect_changed() -> void:
	available_space = size
	if not rendered_first_page_display == null:
		rendered_first_page_display.custom_minimum_size = Vector2(available_space.x, available_space.y)
		rendered_second_page_display.custom_minimum_size = Vector2(available_space.x, available_space.y)
		rendered_single_page_display.custom_minimum_size = Vector2(available_space.x, available_space.y)
		
		rendered_first_page_display.custom_maximum_size = Vector2(available_space.x, available_space.y)
		rendered_second_page_display.custom_maximum_size = Vector2(available_space.x, available_space.y)
		rendered_single_page_display.custom_maximum_size = Vector2(available_space.x, available_space.y)
	if not second_page_container == null:
		second_page_container.set_deferred("scroll_vertical", rendered_second_page_display.custom_maximum_size.y/2 + splitter.split_offsets[0])


func _on_v_split_container_dragged(offset: int) -> void:
	second_page_container.scroll_vertical = size.y/2 + offset

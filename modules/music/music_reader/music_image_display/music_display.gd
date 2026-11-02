extends Control


@onready var rendered_first_page_display = %RenderedFirstPageDisplay
@onready var first_page_container = %FirstPageContainer
@onready var rendered_second_page_display = %RenderedSecondPageDisplay
@onready var second_page_container = %SecondPageContainer
@onready var visibility_timer = %VisibilityTimer
@onready var splitter = %VSplitContainer

var available_space = size

var current_page: Vector2i = Vector2i(0,0)
var files: PackedStringArray
var rendered_pages: Array[ImageTexture] = []

## Should be true when the second part of the page gets flipped (so it is true when the top and
## bottom screen display a different page)
var page_flip: bool = false

var on_visibility_timeout: bool = false

func change_displayed_page(first_page_nr: int, second_page_nr: int) -> void:
	current_page = Vector2i(first_page_nr, second_page_nr)
	rendered_first_page_display.texture = rendered_pages[current_page[0]]
	rendered_second_page_display.texture = rendered_pages[current_page[1]]

 

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
		if event.position.x > size.x / 2 or event.position.y > size.y / 2:
			move_page(1)
		else:
			move_page(-1)


func _on_score_selection_widget_score_selected(files_in: Array) -> void:
	files = files_in
	files.sort()
	render_music()
	change_displayed_page(0,0)
	


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
	if not second_page_container == null:
		second_page_container.set_deferred("scroll_vertical", size.y/2)


func _on_v_split_container_dragged(offset: int) -> void:
	second_page_container.scroll_vertical = size.y/2 + offset

extends Control


@onready var rendered_page_display = %RenderedPageDisplay
@onready var viewport_size: Vector2 = get_viewport().get_visible_rect().size


var current_page: int = 0
var files: PackedStringArray
var rendered_pages: Array[ImageTexture] = []

func change_displayed_page(page_nr: int) -> void:
	current_page = page_nr
	rendered_page_display.texture = rendered_pages[current_page]

 

func render_music():
	for file in files:
		var page_image = Image.load_from_file(file)
		rendered_pages.append(ImageTexture.create_from_image(page_image))



func move_page(direction: int):
	if direction > 0:
		if current_page + direction >= len(rendered_pages):
			return
	if direction < 0:
		if current_page == 0:
			return
	change_displayed_page(current_page + direction)





func _ready() -> void:
	render_music()


func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.is_released():
			if event.position.x > viewport_size.x / 2 or event.position.y > viewport_size.y / 2:
				move_page(1)
			else:
				move_page(-1)

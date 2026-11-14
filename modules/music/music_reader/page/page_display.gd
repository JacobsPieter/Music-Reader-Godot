class_name PageDisplay
extends Control
## One page of sheet music that can be drawn on. Instance this scene once per visible page.
##
## Each instance owns its own strokes, baked layer and live layer, so drawing on one page can
## never show up on another. Colour and brush size come from a shared DrawingTools node.
##
## Layers (all TextureRects filling this control):
##   %SheetMusicPage     - the sheet music image
##   %BakedAnnotations   - every finished stroke, as one SVG texture
##   %LiveAnnotations    - only the stroke currently being drawn, re-rendered each frame

signal strokes_changed

@export var tools: DrawingTools
@export var app_page: MusicDisplay
## Logical size of the page. Strokes are stored in this space, so they survive resizing
## the control, switching between one and two pages, or a different screen.
var page_size := Vector2(1240.0, 1754.0)
## Seconds after the last finished stroke before the page is written to disk.
@export var autosave_delay := 2.0

## Identifies the page on disk: <save dir>/<page_id>.json and <save dir>/<page_id>.svg.
var page_id := ""
var group_name := ""

## Finished strokes only. This is what gets saved as JSON.
var strokes: Array[Stroke] = []
var current_stroke: Stroke = null

## SVG elements of every finished stroke, concatenated.
var _baked_elements := ""
var _baked_texture: DPITexture
var _live_texture: DPITexture
var _live_dirty := false
var _unsaved := false
var _save_timer: Timer

@onready var sheet_music_page: TextureRect = %SheetMusicPage
@onready var baked_layer: TextureRect = %BakedAnnotations
@onready var live_layer: TextureRect = %LiveAnnotations


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(save_page)
	add_child(_save_timer)

	resized.connect(_mark_live_dirty)
	_reset_baked_image()


## Rasterises the live layer at most once per frame, however many drag events arrived.
func _process(_delta: float) -> void:
	if _live_dirty:
		_refresh_live()


func _gui_input(event: InputEvent) -> void:
	if tools.drawing:
		if event is InputEventScreenTouch and event.pressed:
			finish_stroke()
			if _contains(event.position):
				_begin_stroke()
		elif event is InputEventScreenDrag and current_stroke != null:
			if not _contains(event.position):
				# Leaving the page ends the stroke. Re-entering needs a new press.
				finish_stroke()
				return
			current_stroke.add_point(
				_to_page(event.position),
				event.pressure if event.pressure != 0.0 else 1.0,
				event.tilt,
			)
			_mark_live_dirty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		finish_stroke()
		save_page()


func _exit_tree() -> void:
	finish_stroke()
	save_page()


# --- Stroke lifecycle ---------------------------------------------------------------------

func _begin_stroke() -> void:
	current_stroke = Stroke.new()
	# Colour and width are captured here, so later tool changes cannot recolour this stroke.
	current_stroke.colour = tools.get_colour() if tools else Color.BLACK
	current_stroke.width = tools.brush_width if tools else 2.0


## Compresses the active stroke and bakes it into the page. Safe to call at any time.
func finish_stroke() -> void:
	var stroke := current_stroke
	current_stroke = null
	if stroke == null or stroke.points.size() < 2:
		_refresh_live()
		return
	stroke.compress_line()
	strokes.append(stroke)
	_bake_stroke(stroke)
	_refresh_live()  # same frame as the bake, so the stroke is never drawn twice
	_mark_unsaved()
	strokes_changed.emit()


func clear() -> void:
	finish_stroke()
	strokes.clear()
	_reset_baked_image()
	_mark_unsaved()
	strokes_changed.emit()


# --- Rendering ----------------------------------------------------------------------------

func _reset_baked_image() -> void:
	_baked_elements = ""
	_update_baked_texture()


## Re-creates the baked texture from the stroke list, with a single SVG parse.
func rebuild_baked() -> void:
	_baked_elements = ""
	for stroke in strokes:
		_baked_elements += stroke.to_svg()
	_update_baked_texture()


func _bake_stroke(stroke: Stroke) -> void:
	_baked_elements += stroke.to_svg()
	_update_baked_texture()


func _baked_document() -> String:
	return _svg_document(_baked_elements, Rect2(Vector2.ZERO, page_size))


func _update_baked_texture() -> void:
	if _baked_texture == null:
		_baked_texture = DPITexture.create_from_string(_baked_document())
		baked_layer.texture = _baked_texture
	else:
		_baked_texture.set_source(_baked_document())


func _refresh_live() -> void:
	_live_dirty = false
	if current_stroke == null or current_stroke.points.size() < 2 or size.x < 1.0 or size.y < 1.0:
		live_layer.texture = null
		return

	var svg := _svg_document(current_stroke.to_svg(), Rect2(Vector2.ZERO, page_size))
	if _live_texture == null:
		_live_texture = DPITexture.create_from_string(svg)
	else:
		_live_texture.set_source(svg)
	live_layer.texture = _live_texture


## An SVG document showing `view` (in page units). The output is view.size pixels.
func _svg_document(content: String, view: Rect2) -> String:
	return (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%f" height="%f" viewBox="%f %f %f %f">%s</svg>'
		% [view.size.x, view.size.y, view.position.x, view.position.y, view.size.x, view.size.y, content]
	)


func _mark_live_dirty() -> void:
	_live_dirty = true


# --- Coordinates --------------------------------------------------------------------------

func _contains(local_position: Vector2) -> bool:
	var in_rect := sheet_music_page.get_global_transform().affine_inverse() \
			* get_global_transform() * local_position
	return _displayed_rect().has_point(in_rect)


func _displayed_rect() -> Rect2:
	var tex_size := sheet_music_page.texture.get_size()
	var box := sheet_music_page.size
	var s: float = minf(box.x / tex_size.x, box.y / tex_size.y)
	var shown := tex_size * s
	return Rect2((box - shown) / 2.0, shown)



func _to_page(local_position: Vector2) -> Vector2:
	# PageDisplay-local -> TextureRect-local (handles containers moving the rect)
	var in_rect := sheet_music_page.get_global_transform().affine_inverse() \
			* get_global_transform() * local_position
	var shown := _displayed_rect()
	return (in_rect - shown.position) / shown.size * sheet_music_page.texture.get_size()


# --- Persistence --------------------------------------------------------------------------

## Evaluated when used, because page_id is only known after load_page().
func _save_dir() -> String:
	return Settings.score_directory.path_join(group_name).path_join(Settings.annotations_sub_directory)


func _json_path() -> String:
	return _save_dir().path_join(page_id + ".json")


func _svg_path() -> String:
	return _save_dir().path_join(page_id + ".svg")


func _mark_unsaved() -> void:
	_unsaved = true
	_save_timer.start(autosave_delay)


## Writes the stroke list and the baked SVG. Only finished strokes are saved.
func save_page() -> void:
	if page_id.is_empty() or not _unsaved:
		return
	DirAccess.make_dir_recursive_absolute(_save_dir())

	var data := {
		"version": 1,
		"page_size": [page_size.x, page_size.y],
		"strokes": strokes.map(func(stroke: Stroke) -> Dictionary: return stroke.to_dict()),
	}
	var file := FileAccess.open(_json_path(), FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %d)." % [_json_path(), FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()

	var svg_file := FileAccess.open(_svg_path(), FileAccess.WRITE)
	if svg_file == null:
		push_error("Could not write %s (error %d)." % [_svg_path(), FileAccess.get_open_error()])
		return
	svg_file.store_string(_baked_document())
	svg_file.close()
	_unsaved = false


## Saves the current page (if needed) and switches to another one.
func load_page(new_page_id: String, sheet_music_page_texture: Texture2D) -> void:
	finish_stroke()
	save_page()
	_save_timer.stop()
	

	page_id = new_page_id
	strokes.clear()
	_reset_baked_image()
	_unsaved = false
	sheet_music_page.texture = sheet_music_page_texture
	page_size = sheet_music_page.texture.get_size()
	baked_layer.custom_minimum_size = sheet_music_page.custom_minimum_size
	live_layer.custom_minimum_size = sheet_music_page.custom_minimum_size

	var data := _read_json(_json_path())
	if not data.is_empty():
		for entry in data.get("strokes", []):
			strokes.append(Stroke.from_dict(entry))
	rebuild_baked()
	strokes_changed.emit()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

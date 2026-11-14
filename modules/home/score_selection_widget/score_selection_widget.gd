extends Control

@onready var score_click_handler = preload("uid://d3fgbnmwbmqps")
@onready var music_display = preload("uid://du56lrg2b1ndu").instantiate()
@onready var pdf_importer_preload = preload("uid://dkguiekmumbs1")
@onready var score_info_card = preload("uid://cgd38i2ny2cpq")


var pdf_importer: Node

@onready var imported_scores_container = %ScoresContainer

signal score_selected(files: Array, group_name, page_ids)



func display_imported_scores():
	print("display_imported_scores() called")
	print("Import directory: ", Settings.score_directory)
	var page_ids: PackedStringArray = []
	
	for child in imported_scores_container.get_children():
		child.queue_free()
	
	var dir_access = DirAccess.open(Settings.score_directory)

	if dir_access == null:
		print("ERROR: Could not open import directory")
		return

	var directories = dir_access.get_directories()
	print("Found directories: ", directories)

	for dir in directories:
		print("Processing score: ", dir)

		var rendered_path = Settings.score_directory.path_join(dir).path_join(
			Settings.inner_rendered_page_directory
		)
		print("Rendered pages path: ", rendered_path)

		var files = DirAccess.get_files_at(rendered_path)
		files.sort()
		for file in files:
			page_ids.append(file.get_basename())
		print("Files found: ", files)
		
		var files_with_paths = []
		for file in files:
			files_with_paths.append(rendered_path.path_join(file))

		if files.is_empty():
			print("No thumbnail files found!")
			continue

		var thumbnail_path = rendered_path.path_join(files[0])
		var thumbnail_image = Image.load_from_file(thumbnail_path)

		if thumbnail_image == null or thumbnail_image.is_empty():
			print("Failed to load image: ", thumbnail_path)
			continue
		
		var new_card = score_info_card.instantiate()
		new_card.score_group_name = dir.get_basename()
		new_card.files = files_with_paths
		new_card.page_ids = page_ids
		new_card.thumbnail_texture = ImageTexture.create_from_image(thumbnail_image)
		imported_scores_container.add_child(new_card)
		new_card.clickregion.connect("score_selected", _on_score_selected)



		print("Added score UI: ", dir)

	print("Total children in container: ", imported_scores_container.get_child_count())


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	display_imported_scores()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_score_import_button_pressed() -> void:
	pdf_importer = pdf_importer_preload.instantiate()
	add_child(pdf_importer)
	pdf_importer.connect("pdf_loaded", _on_pdf_loaded)

func _on_pdf_loaded(group_name: String, files: PackedStringArray, page_ids: PackedStringArray):
	score_selected.emit(files, group_name, page_ids)
	pdf_importer.queue_free()
	display_imported_scores()


func _on_score_selected(group_name: String, files: PackedStringArray, page_ids: PackedStringArray) -> void:
	score_selected.emit(files, group_name, page_ids)

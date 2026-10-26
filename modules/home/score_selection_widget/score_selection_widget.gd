extends VBoxContainer

@onready var score_click_handler = preload("uid://d3fgbnmwbmqps")
@onready var music_display = preload("uid://du56lrg2b1ndu").instantiate()
@onready var pdf_importer = preload("uid://dkguiekmumbs1").instantiate()

@onready var imported_scores_container = %ScoresContainer


func display_imported_scores():
	print("display_imported_scores() called")
	print("Import directory: ", Settings.import_directory)
	
	for child in imported_scores_container.get_children():
		child.queue_free()
	
	var dir_access = DirAccess.open(Settings.import_directory)

	if dir_access == null:
		print("ERROR: Could not open import directory")
		return

	var directories = dir_access.get_directories()
	print("Found directories: ", directories)

	for dir in directories:
		print("Processing score: ", dir)

		var rendered_path = Settings.import_directory.path_join(dir).path_join(
			Settings.inner_rendered_page_directory
		)
		print("Rendered pages path: ", rendered_path)

		var files = DirAccess.get_files_at(rendered_path)
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
		
		var back_panel = PanelContainer.new()
		back_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		imported_scores_container.add_child(back_panel)

		var score_details = VBoxContainer.new()
		back_panel.add_child(score_details)
		
		var clickregion = score_click_handler.instantiate()
		clickregion.score_group_name = dir.get_basename()
		clickregion.files = files_with_paths
		back_panel.add_child(clickregion)
		clickregion.connect("score_selected", _on_score_selected)
		
		var thumbnail = TextureRect.new()
		thumbnail.texture = ImageTexture.create_from_image(thumbnail_image)
		thumbnail.custom_minimum_size = Vector2(100, 141)
		thumbnail.custom_maximum_size = Vector2(100, 141)
		thumbnail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		thumbnail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		score_details.add_child(thumbnail)

		var score_label = Label.new()
		score_label.text = dir.get_basename()
		score_details.add_child(score_label)
	


		print("Added score UI: ", dir)

	print("Total children in container: ", imported_scores_container.get_child_count())


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	display_imported_scores()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_score_import_button_pressed() -> void:
	add_child(pdf_importer)
	pdf_importer.connect("pdf_loaded", _on_pdf_loaded)

func _on_pdf_loaded(group_name: String, files: PackedStringArray):
	music_display.files = files
	get_parent().add_child(music_display)
	music_display.change_displayed_page(0)


func _on_score_selected(group_name: String, files: Array) -> void:
	music_display.files = files
	get_parent().add_child(music_display)
	music_display.change_displayed_page(0)

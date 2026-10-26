extends Control



@onready var filedialog: FileDialog = %FileDialog
@onready var background: PanelContainer = %Background
@onready var renderer := %PDFRenderer

@onready var import_directory = Settings.import_directory
@onready var inner_rendered_page_dir = Settings.inner_rendered_page_directory


signal pdf_loaded(group_name: String, files: PackedStringArray)


func convert_pdf(local_pdf_path: String, output_dir: String, group_name: String = "") -> void:
	# GDScript can't use C# default values, so every argument must be passed.
	renderer.StartConversion(
		local_pdf_path,				# res://, user:// or absolute path
		output_dir,					# folder, created if missing (use user:// when exported)
		group_name,					# "" = auto-generated, reported back in the signals
		"{name}_page_{page:000}", 	# naming template
		150,						# dpi
		"png",						# "png" or "jpg"
		null						# password (null = none)
	)




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	renderer.connect("ConversionFinished", _on_conversion_finished)
	renderer.connect("ConversionFailed", _on_conversion_failed)
	renderer.connect("PageSaved", _on_page_saved)  # optional
	OS.request_permission("manage_external_storage")
	filedialog.popup_file_dialog()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_file_dialog_file_selected(path: String) -> void:
	var filename = path.uri_decode().get_file()
	var group_name = filename.get_basename()
	var source_file = FileAccess.open(path, FileAccess.READ)
	if not source_file:
		print('Failed to read the selected file: ', FileAccess.get_open_error())
		return
	
	var dest_path = import_directory + group_name
	var dest_file_path = dest_path + "/" + filename
	
	var dir = DirAccess.open('user://')
	if not dir.dir_exists(dest_path):
		dir.make_dir_recursive(dest_path)
	
	var dest_file = FileAccess.open(dest_file_path, FileAccess.WRITE)
	if not dest_file:
		print("Failed to create destination file in user:// ", FileAccess.get_open_error())
		return
	
	var buffer_size = 4096
	while source_file.get_position() < source_file.get_length():
		var data = source_file.get_buffer(min(buffer_size, source_file.get_length() - source_file.get_position()))
		dest_file.store_buffer(data)
	
	source_file.close()
	dest_file.close()
	
	print("PDF successfully imported to: ", dest_file_path)
	
	var rendered_dir = DirAccess.open('user://')
	if not rendered_dir.dir_exists(dest_path + inner_rendered_page_dir):
		rendered_dir.make_dir_recursive(dest_path + inner_rendered_page_dir)

	convert_pdf(dest_file_path, dest_path + inner_rendered_page_dir, group_name)


func _on_conversion_finished(group_name: String, output_dir: String, files: PackedStringArray) -> void:
	print("Done: '%s' -> %d images in %s" % [group_name, files.size(), output_dir])
	pdf_loaded.emit(group_name, files)



func _on_conversion_failed(group_name: String, error: String) -> void:
	push_error("PDF conversion '%s' failed: %s" % [group_name, error])
	# TODO: show an error to the user / retry
 
 
func _on_page_saved(group_name: String, page: int, total_pages: int) -> void:
	# TODO: update a progress bar
	print("%s: page %d/%d" % [group_name, page, total_pages])

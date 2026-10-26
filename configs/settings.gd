extends Node

@export_category("imports")
## The location the score will get saved to, this is the top level directory for all scores
## A specific score should be in its own subfolder using the groupname, below that dir
@export var import_directory = "user://scores/"
## Place where the rendered version of the score should be stored (more specifically a
## series of images (png or jpg format))
@export var inner_rendered_page_directory: String = "/pages/rendered/"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

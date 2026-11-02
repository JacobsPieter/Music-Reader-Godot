extends Control

@onready var thumbnail = %Panel#%Thumbnail
@onready var label = %Label
@onready var clickregion = %ScoreClickHandler


var score_group_name: String = ""
var files: PackedStringArray = []
var thumbnail_texture: ImageTexture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clickregion.score_group_name = score_group_name
	clickregion.files = files
	var new_textured_stylebox = thumbnail.get_theme_stylebox("panel").duplicate()
	new_textured_stylebox.texture = thumbnail_texture
	thumbnail.add_theme_stylebox_override("panel", new_textured_stylebox)
	label.text = score_group_name


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

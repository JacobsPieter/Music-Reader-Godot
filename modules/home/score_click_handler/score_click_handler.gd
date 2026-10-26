extends Button


var score_group_name: String
var files: Array

signal score_selected(score_group_name, files)



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_pressed() -> void:
	print('Pressed!')
	emit_signal("score_selected", score_group_name, files)

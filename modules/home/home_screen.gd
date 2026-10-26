extends Control

@onready var music_display = preload("uid://du56lrg2b1ndu").instantiate()

@onready var score_import_button = %ScoreImportButton
@onready var refresh_home_screen_button = $WidgetscrollContainer/HomeScreenWidgetsContainer/RefreshHomeScreenButton
@onready var score_selection = %ScoreSelectionWidget
@onready var widgets_container = %HomeScreenWidgetsContainer


func refresh_home_screen():
	score_selection.display_imported_scores()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	refresh_home_screen()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass




func _on_refresh_home_screen_button_pressed() -> void:
	refresh_home_screen()

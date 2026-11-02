extends Control

@onready var music_display = preload("uid://du56lrg2b1ndu").instantiate()

@onready var refresh_home_screen_button = %RefreshHomeScreenButton
@onready var score_selection = %ScoreSelectionWidget
@onready var widgets_container = %HomeScreenWidgetsContainer
@onready var page_container = %PageContainer

@export_category("Icon Locations")
@export_dir var active = "res://modules/common/icons/screen_selectors/active/"
@export_dir var inactive = "res://modules/common/icons/screen_selectors/inactive/"
@export_subgroup("Page Selectors")
## Has to be a filename without extention that would link to a file both in the active and inactive directories
## The file should be a .svg file
@export var home_icon = "home"
@export var music_display_icon = "music_display"



var current_tab: int = 0
var directories_dict: Dictionary[String, Dictionary] = {}
var pages_list: Array[String] = ["home", "music_display"]


func refresh_home_screen():
	score_selection.display_imported_scores()

func load_icons():
	directories_dict["home"] = {
		"active": load(active.path_join(home_icon + ".svg")),
		"inactive": load(inactive.path_join(home_icon + ".svg"))
		}
	directories_dict["music_display"] = {
		"active": load(active.path_join(music_display_icon + ".svg")),
		"inactive": load(inactive.path_join(music_display_icon + ".svg"))
		}


func change_tab(tab: int) -> void:
	page_container.set_tab_icon(current_tab, directories_dict[pages_list[current_tab]]["inactive"])
	page_container.set_tab_icon(tab, directories_dict[pages_list[tab]]["active"])
	current_tab = tab



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if OS.has_feature("mobile"):
		get_window().content_scale_factor = 3
	refresh_home_screen()
	load_icons()
	for i in range(len(pages_list)):
		change_tab(i)
	change_tab(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass




func _on_refresh_home_screen_button_pressed() -> void:
	refresh_home_screen()


func _on_tab_container_tab_changed(tab: int) -> void:
	change_tab(tab)


func _on_score_selection_widget_score_selected(files: Array) -> void:
	page_container.current_tab = 1

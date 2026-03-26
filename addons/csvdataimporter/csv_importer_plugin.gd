@tool
extends EditorPlugin

var panel_instance

func _enter_tree():
	# Load the UI scene
	panel_instance = preload("res://addons/csvdataimporter/scene/main_panel.tscn").instantiate()
	# Add the control to the Bottom Panel (where Output/Animation usually are)
	add_control_to_bottom_panel(panel_instance, "CSV Data")

func _exit_tree():
	if panel_instance:
		remove_control_from_bottom_panel(panel_instance)
		panel_instance.queue_free()

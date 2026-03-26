@tool
extends Control

@onready var script_path_edit = %ScriptPath
@onready var dir_path_edit = %DirPath
@onready var csv_path_edit = %CSVPath
@onready var naming_option_button : OptionButton = %NamingOptionButton # Changed from LineEdit to OptionButton
@onready var notify_check = %NotifyCheck # Checkbox
# --- Validation Logic ---

func _ready():
	# Update the list whenever the text is manually changed and focus is lost
	script_path_edit.focus_exited.connect(func(): _update_naming_options(script_path_edit.text))
	_load_plugin_settings()
	# Allow .tres files in the script picker
	script_path_edit.text_changed.connect(_on_script_path_changed)
	notify_check.toggled.connect(_on_notify_check_toggled)

func _validate_inputs(is_import: bool) -> bool:
	# 1. Check if Script exists and is valid
	if not FileAccess.file_exists(script_path_edit.text):
		_notify("CSV Bridge: Script path is invalid.")
		return false
	
	var test_script = load(script_path_edit.text)
	if not test_script is Script:
		_notify("CSV Bridge: The loaded file is not a valid Godot Script.")
		return false

	# 2. Check Directory
	if not DirAccess.dir_exists_absolute(dir_path_edit.text):
		_notify("CSV Bridge: Resource directory does not exist.")
		return false

	# 3. If importing, check if CSV exists
	if is_import:
		if not FileAccess.file_exists(csv_path_edit.text):
			_notify("CSV Bridge: CSV file not found for import.")
			return false
			
	return true

## Clears and repopulates the OptionButton with valid export variables
func _update_naming_options(_new_path: String):
	var current_selected := naming_option_button.get_item_index(naming_option_button.selected)
	naming_option_button.clear()
	
	var path = script_path_edit.text
	if not FileAccess.file_exists(path):
		return
		
	var scr = load(path)
	if not scr is Script:
		return
		
	# Use the logic from our Exporter to get the exact same property list
	var props = ResourceCSVExporter._get_export_properties(scr)
	
	for prop in props:
		if prop == "uid": continue # Don't use UID as a filename choice
		naming_option_button.add_item(prop)
	
	# Try to auto-select 'item_id' or 'item_name' if they exist as sensible defaults
	# 1. First pass: Look for anything containing "name" (e.g., item_name, display_name)
		var found_best_match := false
		for i in range(naming_option_button.item_count):
			var text = naming_option_button.get_item_text(i).to_lower()
			if "name" in text:
				naming_option_button.selected = i
				found_best_match = true
				break
		
		# 2. Second pass: If no "name" found, look for anything containing "id"
		if not found_best_match:
			for i in range(naming_option_button.item_count):
				var text = naming_option_button.get_item_text(i).to_lower()
				if "id" in text:
					naming_option_button.selected = i
					break

# --- Button Actions ---

func _on_export_pressed():
	if not _validate_inputs(false): return
	
	var base_script = load(script_path_edit.text)
	var scan_dir = dir_path_edit.text
	
	_open_file_dialog(
		FileDialog.FILE_MODE_SAVE_FILE,
		["*.csv ; CSV Spreadsheet"],
		func(path): 
			# This code only runs AFTER the user clicks "Save"
			var keep_val = %KeepExportCheck.button_pressed
			ResourceCSVExporter.export_to_csv(base_script, scan_dir, path, keep_val)
			_notify("Success: Data exported to " + path.get_file())
			_save_plugin_settings() # Persistence check
	)

func _on_import_pressed():
	if naming_option_button.selected == -1:
		_notify("Error: Please select a Naming Property first.")
		return
		
	if not _validate_inputs(true): return
	
	var base_script = load(script_path_edit.text)
	var csv_path = csv_path_edit.text
	var output_dir = dir_path_edit.text
	var naming_col = naming_option_button.get_item_text(naming_option_button.selected)
	
	# This call is blocking, so the code waits for it to finish
	ResourceCSVImporter.import_from_csv(base_script, csv_path, output_dir, naming_col)
	
	_notify("Success: Resources imported/updated from CSV.")
	_save_plugin_settings()

# --- Browse Handlers ---

func _on_script_browse_button_pressed() -> void:
	_open_file_dialog(
		FileDialog.FILE_MODE_OPEN_FILE, 
		["*.gd, *.cs, *.tres ; Script or Resource"], 
		func(path): 
			# If a .tres is picked, the _on_script_path_changed logic 
			# we wrote earlier will automatically extract the .gd script
			script_path_edit.text = path
			_on_script_path_changed(path) 
	)

func _on_csv_browse_button_pressed() -> void:
	_open_file_dialog(
		FileDialog.FILE_MODE_OPEN_FILE, 
		["*.csv ; CSV Spreadsheet"], 
		func(path): 
			csv_path_edit.text = path
			_save_plugin_settings()
	)

func _on_resource_dir_browse_button_pressed() -> void:
	_open_file_dialog(
		FileDialog.FILE_MODE_OPEN_DIR, 
		[], 
		func(path): 
			dir_path_edit.text = path
			_save_plugin_settings()
	)

func _on_script_path_changed(new_path: String):
	if new_path.ends_with(".tres"):
		var temp_res = load(new_path)
		if temp_res and temp_res.get_script():
			script_path_edit.text = temp_res.get_script().resource_path
	_update_naming_options(script_path_edit.text)


func _on_notify_check_toggled(button_pressed: bool) -> void:
	_save_plugin_settings()

# --- FileDialog Helper ---

func _open_file_dialog(mode: FileDialog.FileMode, filters: PackedStringArray, callback: Callable):
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = mode
	dialog.filters = filters
	dialog.min_size = Vector2i(700, 500)
	
	dialog.file_selected.connect(callback)
	dialog.dir_selected.connect(callback)
	
	# Add to editor tree and cleanup after use
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.4)
	dialog.visibility_changed.connect(func(): if !dialog.visible: dialog.queue_free())


# --- Persistence Logic ---

func _save_plugin_settings():
	var settings = EditorInterface.get_editor_settings()
	settings.set_project_metadata("csv_bridge", "script_path", script_path_edit.text)
	settings.set_project_metadata("csv_bridge", "dir_path", dir_path_edit.text)
	settings.set_project_metadata("csv_bridge", "show_notifications", notify_check.button_pressed)

func _load_plugin_settings():
	var settings = EditorInterface.get_editor_settings()
	script_path_edit.text = settings.get_project_metadata("csv_bridge", "script_path", "")
	_update_naming_options(script_path_edit.text)
	dir_path_edit.text = settings.get_project_metadata("csv_bridge", "dir_path", "res://")
	notify_check.button_pressed = settings.get_project_metadata("csv_bridge", "show_notifications", true)

# --- Notification Logic ---

func _notify(message: String):
	print(message)
	if notify_check.button_pressed:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = message
		add_child(dialog)
		dialog.popup_centered()

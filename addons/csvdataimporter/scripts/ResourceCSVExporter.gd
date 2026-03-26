@tool
extends Node
class_name ResourceCSVExporter

static func export_to_csv(base_script: Script, scan_path: String, save_path: String, keep_csv_export : bool = true):
	# 1. Get headers and prepend "uid" as the first column
	var export_props = _get_export_properties(base_script)
	var headers = PackedStringArray(["uid"])
	headers.append_array(PackedStringArray(export_props))
	
	var csv_rows: Array[PackedStringArray] = []
	csv_rows.append(headers)
	
	# 2. Scan for files
	var files = _get_all_files(scan_path, ".tres")
	
	for file_path in files:
		var res = load(file_path)
		# Check if the resource uses our script
		if res and res.get_script() and (res.get_script() == base_script or res.get_script().get_base_script() == base_script):
			var row = PackedStringArray()
			
			# A. Get the UID for THIS resource
			var self_uid_int = ResourceLoader.get_resource_uid(file_path)
			var self_uid_text = ""
			
			if self_uid_int != -1:
				self_uid_text = ResourceUID.id_to_text(self_uid_int)
			else:
				# Fallback if no UID exists yet (Godot usually assigns these on save/import)
				self_uid_text = file_path 
			
			row.append(self_uid_text)
			
			# B. Get the rest of the exported variables
			for property in export_props:
				var value = res.get(property)
				row.append(_serialize_value(value))
				
			csv_rows.append(row)
	
	# 3. Save the File
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		for row in csv_rows:
			file.store_csv_line(row)
		file.close()
		_create_import_file(save_path)
		print("CSV Bridge: Exported %d resources to %s" % [csv_rows.size() - 1, save_path])

static func _serialize_value(val) -> String:
	if val == null: return ""
	
	# If the value is a Resource (like an icon or sub-resource), export ITS uid
	if val is Resource:
		if not val.resource_path.is_empty():
			var uid_int = ResourceLoader.get_resource_uid(val.resource_path)
			if uid_int != -1:
				return ResourceUID.id_to_text(uid_int)
			return val.resource_path
		return ""
	
	# Handle common types
	if val is Array or val is Dictionary:
		return JSON.stringify(val)
	if val is Color:
		return "#" + val.to_html(true)
	if val is Vector2 or val is Vector3 or val is Rect2:
		return str(val) # Default Godot string format "(x, y)" is fine for our math parser
		
	return str(val)

static func _get_export_properties(script: Script) -> Array[String]:
	var props: Array[String] = []
	var temp = script.new()
	var blacklist = ["resource_local_to_scene", "resource_path", "resource_name", "script"]
	
	for p in temp.get_property_list():
		if p.name in blacklist: continue
		if p.usage & PROPERTY_USAGE_EDITOR and p.usage & PROPERTY_USAGE_STORAGE:
			props.append(p.name)
	return props

static func _create_import_file(path: String, keep_csv_export := true):
	var f = FileAccess.open(path + ".import", FileAccess.WRITE)
	
	# Determine the string value based on the boolean
	var importer_type = "keep" if keep_csv_export else "skip"
	
	# Construct the .import file content
	var content = "[remap]\n\nimporter=\"%s\"\n" % importer_type
	
	f.store_string(content)
	f.close()

static func _get_all_files(path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				files.append_array(_get_all_files(path.path_join(file_name), extension))
			elif file_name.ends_with(extension):
				files.append(path.path_join(file_name))
			file_name = dir.get_next()
	return files

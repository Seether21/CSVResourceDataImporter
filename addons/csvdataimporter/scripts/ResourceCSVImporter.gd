@tool
extends Node
class_name ResourceCSVImporter

static func import_from_csv(base_script: Script, csv_path: String, output_dir: String, naming_column: String):
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file: return
	
	var headers = Array(file.get_csv_line())
	var property_map = _get_script_property_map(base_script)

	while !file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < headers.size(): continue

		#Skip the line if it's identical to the header row
		if line[0] == headers[0] and line[-1] == headers[-1]:
			continue

		var res: Resource = null
		
		var existing_path: String = ""
		
		# 1. Try to find existing resource via UID
		if headers[0] == "uid" and line[0].begins_with("uid://"):
			var uid_val = line[0]
			if ResourceLoader.exists(uid_val):
				res = load(uid_val)
				existing_path = res.resource_path
		
		# 2. If no UID match, create a new instance
		if not res:
			res = base_script.new()
		
		var file_name_from_column = ""
		
		# 3. Decode and assign properties
		for i in range(headers.size()):
			var prop_name = headers[i]
			var raw_val = line[i]
			
			if not property_map.has(prop_name): continue
			
			var prop_info = property_map[prop_name]
			var typed_val = _decode_to_type(raw_val, prop_info)
			
			if prop_name == naming_column:
				file_name_from_column = str(raw_val).validate_filename()
			
			_assign_value(res, prop_name, typed_val)
		
		# 4. Determine final save path
		var final_save_path: String = ""
		
		if not existing_path.is_empty():
			# Keep original location and name
			final_save_path = existing_path
		else:
			# Use output directory and naming column
			if file_name_from_column.is_empty():
				file_name_from_column = "imported_" + str(res.get_instance_id())
			final_save_path = output_dir.path_join(file_name_from_column + ".tres")
			
		ResourceSaver.save(res, final_save_path)
		
	file.close()

## Helper to extract type metadata from the script
static func _get_script_property_map(script: Script) -> Dictionary:
	var map = {}
	var temp = script.new()
	for p in temp.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			map[p.name] = p
	return map


static func _decode_to_type(raw: String, info: Dictionary):
	if raw.is_empty(): return null
	
	match info.type:
		TYPE_INT: return raw.to_int()
		TYPE_FLOAT: return raw.to_float()
		TYPE_BOOL: return raw.to_lower() == "true" or raw == "1"
		TYPE_STRING, TYPE_STRING_NAME: return raw
		TYPE_COLOR: return _handle_color(raw)
		TYPE_OBJECT: return _handle_object(raw, info)
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY: 
			return _handle_array(raw, info)
		TYPE_DICTIONARY: return _handle_dictionary(raw, info)
		
		# Unified Math Handling (Vectors, Rects, etc.)
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I:
			return _handle_math_type(raw, info.type)
			
	return raw # Fallback: return as string

static func _handle_color(raw: String) -> Color:
	# Clean string: remove "Color", "(", ")", and spaces
	var clean = raw.replace("Color", "").replace("(", "").replace(")", "").replace(" ", "")
	
	if clean.begins_with("#"):
		return Color.from_string(clean, Color.WHITE)
	
	var parts = clean.split(",")
	if parts.size() >= 3:
		return Color(
			float(parts[0]), 
			float(parts[1]), 
			float(parts[2]), 
			float(parts[3]) if parts.size() > 3 else 1.0
		)
	return Color.WHITE

static func _handle_object(raw: String, info: Dictionary):
	# If it's a Resource/Texture/Scene, we expect a path
	if raw.begins_with("res://"):
		return load(raw)
	return null

static func _handle_array(raw: String, info: Dictionary) -> Array:
	var json = JSON.new()
	if json.parse(raw) != OK or not json.data is Array:
		return []
	
	var data = json.data
	
	# If untyped, return as-is (strings/numbers from JSON)
	if info.hint_string.is_empty():
		return data

	# Godot 4 hint_string for Array[Type] is usually "type_index:class_name"
	# Example: Array[Resource] -> "24:Resource" (TYPE_OBJECT is 24)
	var type_parts = info.hint_string.split(":")
	var element_type = type_parts[0].to_int()
	
	# Create a pseudo-property info for the array elements to reuse our decoders
	var element_info = {
		"type": element_type,
		"hint_string": type_parts[1] if type_parts.size() > 1 else ""
	}

	var result = []
	for item in data:
		# Recursively decode each element using the element's expected type
		result.append(_decode_to_type(str(item), element_info))
		
	return result


static func _handle_dictionary(raw: String, info: Dictionary) -> Dictionary:
	var json = JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return {}
	
	var data = json.data
	
	# If untyped, return the raw JSON dictionary
	if info.hint_string.is_empty():
		return data

	# Godot 4 hint_string for Dictionary[Key, Value] is "key_type:value_type"
	# Example: Dictionary[StringName, float] -> "21:3"
	var type_parts = info.hint_string.split(":")
	if type_parts.size() < 2:
		return data # Fallback to untyped if hint is malformed
		
	var key_info = {"type": type_parts[0].to_int(), "hint_string": ""}
	var val_info = {"type": type_parts[1].to_int(), "hint_string": ""}

	var result = {}
	for key in data:
		var typed_key = _decode_to_type(str(key), key_info)
		var typed_val = _decode_to_type(str(data[key]), val_info)
		result[typed_key] = typed_val
		
	return result


static func _handle_math_type(raw: String, type: int):
	# Clean string: remove "(", ")", "[", "]", and spaces
	var clean = raw.replace("(", "").replace(")", "").replace("[", "").replace("]", "").replace(" ", "")
	var p = clean.split(",")
	var f = []
	for s in p: f.append(float(s))
	
	match type:
		TYPE_VECTOR2:  return Vector2(f[0], f[1])
		TYPE_VECTOR2I: return Vector2i(int(f[0]), int(f[1]))
		TYPE_VECTOR3:  return Vector3(f[0], f[1], f[2])
		TYPE_VECTOR3I: return Vector3i(int(f[0]), int(f[1]), int(f[2]))
		TYPE_VECTOR4:  return Vector4(f[0], f[1], f[2], f[3])
		TYPE_VECTOR4I: return Vector4i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
		TYPE_RECT2:    return Rect2(f[0], f[1], f[2], f[3])
		TYPE_RECT2I:   return Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
	return null


static func _assign_value(target: Resource, prop: String, value):
	var current = target.get(prop)
	
	if current is Dictionary and value is Dictionary:
		current.clear()
		for key in value:
			# Automatically handles String to StringName conversion
			current[key] = value[key]
	elif current is Array and value is Array:
		current.clear()
		current.append_array(value)
	else:
		target.set(prop, value)

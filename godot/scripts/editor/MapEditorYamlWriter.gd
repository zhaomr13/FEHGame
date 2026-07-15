class_name MapEditorYamlWriter
extends RefCounted

const DEFAULT_PATH := "res://data/world_map.yaml"

static func load_world_map(path: String = DEFAULT_PATH) -> Dictionary:
	var result := {"metadata": {}, "cities": []}
	if not FileAccess.file_exists(path):
		push_error("MapEditorYamlWriter: file not found: " + path)
		return result

	var yaml_text := FileAccess.get_file_as_string(path)
	var parser := YamlParser.new()
	var parsed := parser.parse(yaml_text)
	if parsed == null or not parsed is Dictionary:
		push_error("MapEditorYamlWriter: failed to parse YAML")
		return result

	result["metadata"] = parsed.get("metadata", {})
	if parsed.has("manual_connections"):
		result["metadata"]["manual_connections"] = parsed.get("manual_connections", [])
	result["cities"] = parsed.get("nodes", [])
	return result

static func write_world_map(metadata: Dictionary, cities: Array, path: String = DEFAULT_PATH) -> bool:
	var lines: Array[String] = [
		"# World Map Data",
		"# Cities/forts/villages, positions, factions, and connection overrides",
		""
	]

	lines.append_array(_emit_metadata(metadata))
	lines.append("nodes:")
	for city in cities:
		lines.append_array(_emit_city(city))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("MapEditorYamlWriter: failed to open file for writing: " + path)
		return false
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return true

static func _emit_metadata(metadata: Dictionary) -> Array[String]:
	var lines: Array[String] = ["metadata:"]
	for key in metadata.keys():
		if key == "manual_connections":
			continue
		_emit_yaml_value(lines, key, metadata[key], 2)

	if metadata.has("manual_connections"):
		var manual_connections = metadata["manual_connections"]
		if manual_connections is Array:
			lines.append("manual_connections:")
			for link in manual_connections:
				if link is Dictionary:
					lines.append('  - from: "%s"' % _escape(str(link.get("from", ""))))
					lines.append('    to: "%s"' % _escape(str(link.get("to", ""))))
				else:
					lines.append("  - " + str(link))

	lines.append("")
	return lines

static func _emit_yaml_value(lines: Array[String], key: String, value, indent: int):
	var prefix := " ".repeat(indent)
	if value is Dictionary:
		lines.append(prefix + key + ":")
		for sub_key in value.keys():
			_emit_yaml_value(lines, sub_key, value[sub_key], indent + 2)
	elif value is Array:
		lines.append(prefix + key + ":")
		for item in value:
			_emit_yaml_array_item(lines, item, indent + 2)
	elif value is String:
		lines.append(prefix + key + ': "' + _escape(value) + '"')
	else:
		lines.append(prefix + key + ": " + str(value))

static func _emit_yaml_array_item(lines: Array[String], item, indent: int):
	var prefix := " ".repeat(indent)
	if item is Dictionary:
		var first := true
		for sub_key in item.keys():
			var label := str(sub_key)
			var sub_value = item[sub_key]
			var value_str := _scalar(sub_value)
			if first:
				lines.append(prefix + "- " + label + ": " + value_str)
				first = false
			else:
				lines.append(" ".repeat(indent + 2) + label + ": " + value_str)
	elif item is String:
		lines.append(prefix + '- "' + _escape(item) + '"')
	else:
		lines.append(prefix + "- " + str(item))

static func _scalar(value) -> String:
	if value is String:
		return '"' + _escape(value) + '"'
	return str(value)

static func _emit_city(city: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append('  - id: "%s"' % city.get("id", ""))
	lines.append('    name: "%s"' % _escape(city.get("name", "")))
	lines.append('    type: "%s"' % city.get("type", "city"))

	var icon_size: String = city.get("icon_size", "")
	if icon_size != "":
		lines.append('    icon_size: "%s"' % icon_size)

	var pos = city.get("pos", {})
	lines.append("    pos:")
	lines.append("      x: %d" % int(pos.get("x", 0)))
	lines.append("      y: %d" % int(pos.get("y", 0)))

	var faction: String = city.get("faction", "")
	lines.append('    faction: "%s"' % faction)

	var force_connections: Array = city.get("force_connections", [])
	if force_connections.size() > 0:
		lines.append("    force_connections:")
		for conn in force_connections:
			lines.append('      - "%s"' % conn)

	var blocked_neighbors: Array = city.get("blocked_neighbors", [])
	if blocked_neighbors.size() > 0:
		lines.append("    blocked_neighbors:")
		for blocked in blocked_neighbors:
			lines.append('      - "%s"' % blocked)

	return lines

static func _escape(value: String) -> String:
	var result := ""
	for ch in value:
		match ch:
			"\\": result += "\\\\"
			"\"": result += "\\\""
			"\t": result += "\\t"
			"\n": result += "\\n"
			"\r": result += "\\r"
			_: result += ch
	return result

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
	var map_size = metadata.get("map_size", {})
	lines.append("  map_size:")
	lines.append("    x: %d" % map_size.get("x", 3840))
	lines.append("    y: %d" % map_size.get("y", 2160))
	lines.append('  connection_strategy: "%s"' % metadata.get("connection_strategy", "manual"))
	lines.append("  max_auto_distance: %d" % metadata.get("max_auto_distance", 320))
	lines.append("  target_connections: %d" % metadata.get("target_connections", 3))
	lines.append("")
	return lines

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
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

class_name YamlParser
extends RefCounted

# Lightweight YAML parser for a restricted subset:
# - Comments (# to end of line)
# - Block-style lists (- item) and dictionaries (key: value)
# - Nested structures via indentation (spaces only)
# - Scalars: quoted/unquoted strings, ints, floats, booleans, null
# NOT supported: anchors/aliases, multi-line strings (| >), flow style ({...}, [...]), tags

func parse(text: String) -> Dictionary:
	var lines := _preprocess(text)
	var parsed := _parse_dict(lines, 0, 0)
	return parsed.value

func _preprocess(text: String) -> Array[Dictionary]:
	var raw_lines := text.split("\n")
	var lines: Array[Dictionary] = []
	for raw in raw_lines:
		# Strip comments
		var comment_pos := raw.find("#")
		if comment_pos >= 0:
			raw = raw.substr(0, comment_pos)
		var stripped := raw.strip_edges()
		if stripped == "":
			continue
		var indent := _count_indent(raw)
		lines.append({"indent": indent, "content": stripped})
	return lines

func _count_indent(line: String) -> int:
	var count := 0
	for c in line:
		if c == " ":
			count += 1
		elif c == "\t":
			count += 4
		else:
			break
	return count

func _parse_value(lines: Array[Dictionary], index: int, base_indent: int) -> Dictionary:
	if index >= lines.size():
		return {"value": null, "next_index": index}
	if lines[index].content.begins_with("- "):
		return _parse_list(lines, index, base_indent)
	return _parse_dict(lines, index, base_indent)

func _parse_list(lines: Array[Dictionary], start: int, base_indent: int) -> Dictionary:
	var result: Array = []
	var i := start
	while i < lines.size():
		var line := lines[i]
		if line.indent < base_indent:
			break
		if line.indent > base_indent or not line.content.begins_with("- "):
			break

		var item_text: String = line.content.substr(2).strip_edges()
		if item_text == "":
			# Nested value follows
			var nested := _parse_value(lines, i + 1, base_indent + 2)
			result.append(nested.value)
			i = nested.next_index
		elif item_text.contains(":"):
			# Dict item: parse first key, then sibling keys at nested indent
			var item_dict := _parse_inline_dict_start(item_text)
			i += 1
			if item_dict.is_empty():
				# "- key:" with value on following lines
				var first_key: String = item_text.substr(0, item_text.find(":")).strip_edges()
				var nested := _parse_value(lines, i, base_indent + 2)
				item_dict[first_key] = nested.value
				i = nested.next_index
			else:
				# First key had an inline value; read any sibling keys
				var siblings := _parse_dict(lines, i, base_indent + 2)
				for k in siblings.value.keys():
					item_dict[k] = siblings.value[k]
				i = siblings.next_index
			result.append(item_dict)
		else:
			result.append(_parse_scalar(item_text))
			i += 1
	return {"value": result, "next_index": i}

func _parse_dict(lines: Array[Dictionary], start: int, base_indent: int) -> Dictionary:
	var result := {}
	var i := start
	while i < lines.size():
		var line := lines[i]
		if line.indent < base_indent:
			break
		if line.indent > base_indent:
			i += 1
			continue
		if line.content.begins_with("- "):
			break
		var colon_pos: int = line.content.find(":")
		if colon_pos < 0:
			break
		var key: String = line.content.substr(0, colon_pos).strip_edges()
		var rest: String = line.content.substr(colon_pos + 1).strip_edges()
		if rest == "":
			var nested := _parse_value(lines, i + 1, base_indent + 2)
			result[key] = nested.value
			i = nested.next_index
		else:
			result[key] = _parse_scalar(rest)
			i += 1
	return {"value": result, "next_index": i}

func _parse_inline_dict_start(text: String) -> Dictionary:
	var colon_pos: int = text.find(":")
	var key: String = text.substr(0, colon_pos).strip_edges()
	var rest: String = text.substr(colon_pos + 1).strip_edges()
	var result := {}
	if rest != "":
		result[key] = _parse_scalar(rest)
	return result

func _parse_scalar(text: String) -> Variant:
	text = text.strip_edges()
	if text.is_empty():
		return ""

	# Quoted strings
	if (text.begins_with("\"") and text.ends_with("\"")) or (text.begins_with("'") and text.ends_with("'")):
		return text.substr(1, text.length() - 2)

	# Null
	if text == "null" or text == "~":
		return null

	# Booleans
	var lower := text.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false

	# Int
	if text.is_valid_int():
		return text.to_int()

	# Float
	if text.is_valid_float():
		return text.to_float()

	# Unquoted string
	return text

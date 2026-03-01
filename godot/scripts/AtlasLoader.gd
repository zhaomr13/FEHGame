extends Node
## Runtime atlas loader - creates SpriteFrames from JSON atlas without plugin

static func load_atlas(json_path: String, png_path: String) -> SpriteFrames:
	var sprite_frames = SpriteFrames.new()

	# Load JSON
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open: " + json_path)
		return sprite_frames

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return sprite_frames

	var data = json.data
	var frames = data["frames"]
	var meta = data["meta"]
	var tags = meta.get("frameTags", [])

	# Load PNG texture using load() for proper import
	var full_texture = load(png_path) as Texture2D
	if full_texture == null:
		push_error("Failed to load texture: " + png_path)
		return sprite_frames

	# Create animations from tags
	for tag in tags:
		var anim_name = tag["name"]
		var from_frame = tag["from"]
		var to_frame = tag["to"]

		# Add animation to SpriteFrames
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_loop(anim_name, true)
		sprite_frames.set_animation_speed(anim_name, 30.0)

		# Add frames to animation
		for i in range(from_frame, to_frame + 1):
			if i >= frames.size():
				continue

			var frame_data = frames[i]
			var rect = frame_data["frame"]

			# Create AtlasTexture for this frame
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = full_texture
			atlas_tex.region = Rect2(
				rect["x"], rect["y"],
				rect["w"], rect["h"]
			)

			# Calculate duration (convert ms to seconds, then to frames at 30fps)
			var duration_ms = frame_data.get("duration", 33)
			var duration_frames = max(1, round(duration_ms / 33.33))

			sprite_frames.add_frame(anim_name, atlas_tex, duration_frames)

	return sprite_frames

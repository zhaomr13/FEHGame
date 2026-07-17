extends Node
## Runtime atlas loader - creates SpriteFrames from JSON atlas without plugin

static var _cache: Dictionary = {}
static var _mutex := Mutex.new()

## Load all animations from a character folder (e.g., res://assets/characters/char_01_alm/)
## Thread-safe: the GameManager preload thread and on-demand loads from the
## main thread may call this concurrently; the mutex also prevents duplicate
## loads of the same folder.
static func load_character_atlas(character_folder: String) -> SpriteFrames:
	_mutex.lock()
	var result = _load_character_atlas_locked(character_folder)
	_mutex.unlock()
	return result

static func _load_character_atlas_locked(character_folder: String) -> SpriteFrames:
	if _cache.has(character_folder):
		return _cache[character_folder]

	var sprite_frames = SpriteFrames.new()

	# List of animation names to load
	var anim_names = ["Idle", "Attack1", "Attack2", "Damage", "Ready", "Start", "Ok", "Jump"]

	for anim_name in anim_names:
		var json_path = character_folder + "/" + anim_name + ".json"
		var png_path = character_folder + "/" + anim_name + ".png"

		# Check if files exist
		if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
			continue

		_load_single_animation(sprite_frames, anim_name, json_path, png_path)

	_cache[character_folder] = sprite_frames
	return sprite_frames

## Load a single animation into existing SpriteFrames
static func _load_single_animation(sprite_frames: SpriteFrames, anim_name: String, json_path: String, png_path: String) -> void:
	# Load JSON
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件：" + json_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON 解析错误：" + json.get_error_message())
		return

	var data = json.data
	var frames = data["frames"]

	# Load PNG texture
	var full_texture = load(png_path) as Texture2D
	if full_texture == null:
		push_error("无法加载纹理：" + png_path)
		return

	# Add animation to SpriteFrames
	sprite_frames.add_animation(anim_name)
	# Only loop idle animations, not attacks or one-shots
	var should_loop = anim_name in ["Idle", "Attack1_Loop", "Attack2_Loop"]
	sprite_frames.set_animation_loop(anim_name, should_loop)
	sprite_frames.set_animation_speed(anim_name, 60.0)

	# Add frames to animation
	for i in range(frames.size()):
		var frame_data = frames[i]
		var rect = frame_data["frame"]

		# Create AtlasTexture for this frame
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = full_texture
		atlas_tex.region = Rect2(
			rect["x"], rect["y"],
			rect["w"], rect["h"]
		)

		# Calculate duration (convert ms to seconds, then to frames)
		var duration_ms = frame_data.get("duration", 83)
		var duration_frames = max(1, round(duration_ms / 83.33))

		sprite_frames.add_frame(anim_name, atlas_tex, duration_frames)

static func load_atlas(json_path: String, png_path: String) -> SpriteFrames:
	_mutex.lock()
	var result = _load_atlas_locked(json_path, png_path)
	_mutex.unlock()
	return result

static func _load_atlas_locked(json_path: String, png_path: String) -> SpriteFrames:
	var cache_key = json_path + "|" + png_path
	if _cache.has(cache_key):
		return _cache[cache_key]

	var sprite_frames = SpriteFrames.new()

	# Load JSON
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件：" + json_path)
		return sprite_frames

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON 解析错误：" + json.get_error_message())
		return sprite_frames

	var data = json.data
	var frames = data["frames"]
	var meta = data["meta"]
	var tags = meta.get("frameTags", [])

	# Load PNG texture using load() for proper import
	var full_texture = load(png_path) as Texture2D
	if full_texture == null:
		push_error("无法加载纹理：" + png_path)
		return sprite_frames

	# Create animations from tags
	for tag in tags:
		var anim_name = tag["name"]
		var from_frame = tag["from"]
		var to_frame = tag["to"]

		# Add animation to SpriteFrames
		sprite_frames.add_animation(anim_name)
		# Only loop idle animations, not attacks or one-shots
		var should_loop = anim_name in ["Idle", "Attack1_Loop", "Attack2_Loop"]
		sprite_frames.set_animation_loop(anim_name, should_loop)
		sprite_frames.set_animation_speed(anim_name, 60.0)

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

	_cache[cache_key] = sprite_frames
	return sprite_frames

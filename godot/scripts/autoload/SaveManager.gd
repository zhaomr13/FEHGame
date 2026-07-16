extends Node

const SAVE_PATH = "user://savegame.json"
const SQUAD_SAVE_PATH = "user://squads.json"
const SQUAD_SAVE_VERSION = 2

# Optional override for tests or alternative game managers.
var game_manager: Node = null

func _get_gm() -> Node:
	if game_manager != null:
		return game_manager
	return Engine.get_singleton("GameManager")

func save_game():
	var save_data = {
		"chapter": _get_gm().current_chapter,
		"gold": _get_gm().player_gold,
		"current_faction": _get_gm().current_faction,
		"player_army": []
	}

	for character in _get_gm().player_army:
		save_data["player_army"].append({
			"name": character.character_name,
			"class": character.character_class,
			"level": character.level,
			"exp": character.experience,
			"hp": character.current_hp,
			"max_hp": character.max_hp,
			"attack": character.attack,
			"defense": character.defense,
			"speed": character.speed,
			"leadership": character.leadership,
			"weapon_type": character.weapon_type,
			"soldiers": character.soldiers,
			"max_soldiers": character.max_soldiers,
			"faction": character.faction,
			"sprite_frames_path": character.sprite_frames_path,
			"skills": _serialize_skills(character.skills),
			"tactics": _serialize_tactics(character.tactics)
		})

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("游戏已保存到 ", SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("未找到存档文件")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON 解析错误：", json.get_error_message())
		return false

	var save_data = json.data
	_get_gm().current_chapter = save_data.get("chapter", 1)
	_get_gm().player_gold = save_data.get("gold", 1000)
	_get_gm().current_faction = save_data.get("current_faction", _get_gm().current_faction)

	# Restore player army from save data
	_get_gm().player_army.clear()
	var army_data = save_data.get("player_army", [])
	for char_data in army_data:
		var character = CharacterData.new()
		character.character_name = char_data.get("name", "Unknown")
		character.character_class = char_data.get("class", GameConstants.CharacterClass.LORD)
		character.level = char_data.get("level", 1)
		character.experience = char_data.get("exp", 0)
		character.current_hp = char_data.get("hp", 20)
		character.max_hp = char_data.get("max_hp", 20)
		character.attack = char_data.get("attack", 5)
		character.defense = char_data.get("defense", 3)
		character.speed = char_data.get("speed", 5)
		character.leadership = char_data.get("leadership", 5)
		character.weapon_type = char_data.get("weapon_type", "sword")
		character.soldiers = char_data.get("soldiers", 100)
		character.max_soldiers = char_data.get("max_soldiers", character.soldiers)
		character.faction = char_data.get("faction", _get_gm().current_faction)
		character.sprite_frames_path = char_data.get("sprite_frames_path", "")
		character.skills = _deserialize_skills(char_data.get("skills", []))
		character.tactics = _deserialize_tactics(char_data.get("tactics", []))
		if character.tactics.is_empty():
			character.setup_default_tactics()
		_get_gm().player_army.append(character)

	# Load squad configuration
	if has_saved_squads():
		_get_gm().squad_data = load_squads()
		_get_gm().unassigned_units = load_unassigned()
	else:
		_get_gm().initialize_squads()

	print("游戏已从 ", SAVE_PATH, " 加载")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Squad save/load functions
func save_squads(squads: Array, unassigned: Array[CharacterData]):
	"""Save squad configuration to file"""
	var squad_names: Array = []
	for squad in squads:
		var names: Array = []
		for character in squad:
			names.append(character.character_name)
		squad_names.append(names)

	var unassigned_names: Array = []
	for character in unassigned:
		unassigned_names.append(character.character_name)

	var squad_save = {
		"version": SQUAD_SAVE_VERSION,
		"squads": squad_names,
		"unassigned": unassigned_names
	}

	var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(squad_save))
	file.close()
	print("小队配置已保存")

func load_squads() -> Array:
	"""Load squad configuration from file"""
	var result: Array = []
	var squad_save = _load_squad_save_data()
	if squad_save.is_empty():
		return _pad_squads(result)

	var saved_squads = squad_save.get("squads", [])
	var character_lookup = _build_character_lookup()

	if _is_legacy_format(squad_save):
		# Legacy v1: fixed 3 squads
		for i in range(3):
			var squad: Array = []
			var squad_names = saved_squads[i] if i < saved_squads.size() else []
			for name in squad_names:
				if character_lookup.has(name):
					squad.append(character_lookup[name])
			result.append(squad)
	else:
		# v2: dynamic squads
		for squad_names in saved_squads:
			var squad: Array = []
			for name in squad_names:
				if character_lookup.has(name):
					squad.append(character_lookup[name])
			result.append(squad)

	return _pad_squads(result)

func load_unassigned() -> Array[CharacterData]:
	"""Load unassigned characters from file"""
	var result: Array[CharacterData] = []
	var squad_save = _load_squad_save_data()
	if squad_save.is_empty():
		return result

	var character_lookup = _build_character_lookup()
	var unassigned_names = squad_save.get("unassigned", [])
	for name in unassigned_names:
		if character_lookup.has(name):
			result.append(character_lookup[name])

	return result

func has_saved_squads() -> bool:
	"""Check if squad configuration exists"""
	return FileAccess.file_exists(SQUAD_SAVE_PATH)

func _load_squad_save_data() -> Dictionary:
	"""Load and parse squad save file. Returns an empty Dictionary on failure."""
	if not FileAccess.file_exists(SQUAD_SAVE_PATH):
		return {}

	var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("小队 JSON 解析错误：", json.get_error_message())
		return {}

	if json.data is Dictionary:
		return json.data
	return {}

func _build_character_lookup() -> Dictionary:
	"""Build a name -> CharacterData lookup from player_army."""
	var character_lookup = {}
	for character in _get_gm().player_army:
		character_lookup[character.character_name] = character
	return character_lookup

func _is_legacy_format(squad_save: Dictionary) -> bool:
	"""Return true if the save uses the legacy v1 fixed 3-squad format."""
	var version = squad_save.get("version", 1)
	return version < 2

func _pad_squads(squads: Array) -> Array:
	"""Pad squad array up to MAX_SQUADS with empty squads for UI consistency."""
	while squads.size() < GameConstants.MAX_SQUADS:
		squads.append([])
	return squads

func _serialize_tactics(tactics: Array) -> Array:
	var result: Array = []
	for tactic in tactics:
		if tactic is Tactic:
			result.append({
				"priority": tactic.priority,
				"condition_type": tactic.condition_type,
				"condition_value": tactic.condition_value,
				"target_type": tactic.target_type,
				"action_type": tactic.action_type,
				"use_skill": tactic.use_skill
			})
	return result

func _deserialize_tactics(tactics_data: Array) -> Array[Tactic]:
	var result: Array[Tactic] = []
	for tactic_data in tactics_data:
		if tactic_data is Dictionary:
			var tactic := Tactic.new()
			tactic.priority = tactic_data.get("priority", 1)
			tactic.condition_type = tactic_data.get("condition_type", Tactic.ConditionType.ALWAYS)
			tactic.condition_value = tactic_data.get("condition_value", 0.5)
			tactic.target_type = tactic_data.get("target_type", Tactic.TargetType.NEAREST)
			tactic.action_type = tactic_data.get("action_type", Tactic.ActionType.ATTACK)
			tactic.use_skill = tactic_data.get("use_skill", false)
			result.append(tactic)
	return result

func _serialize_skills(skills: Array) -> Array:
	var result: Array = []
	for skill in skills:
		if skill is SkillData:
			result.append({
				"skill_name": skill.skill_name,
				"description": skill.description,
				"skill_type": skill.skill_type,
				"target_type": skill.target_type,
				"power": skill.power,
				"cooldown": skill.cooldown,
				"current_cooldown": skill.current_cooldown
			})
	return result

func _deserialize_skills(skills_data: Array) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill_data in skills_data:
		if skill_data is Dictionary:
			var skill := SkillData.new()
			skill.skill_name = skill_data.get("skill_name", "Unknown Skill")
			skill.description = skill_data.get("description", "")
			skill.skill_type = skill_data.get("skill_type", SkillData.SkillType.ACTIVE)
			skill.target_type = skill_data.get("target_type", SkillData.TargetType.SINGLE)
			skill.power = skill_data.get("power", 10)
			skill.cooldown = skill_data.get("cooldown", 3)
			skill.current_cooldown = skill_data.get("current_cooldown", 0)
			result.append(skill)
	return result

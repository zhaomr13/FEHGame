extends SceneTree

# Verifies save serialization:
#  1. CharacterData.to_dict/from_dict round-trips every field through JSON
#  2. from_dict fills default tactics/faction when absent
#  3. SaveManager.save_game writes a versioned file and load_game restores it
#     (any pre-existing user save is backed up and restored afterwards)

var failures := 0

func check(cond: bool, msg: String):
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize():
	call_deferred("_run")

func _make_character() -> CharacterData:
	var c = CharacterData.new()
	c.character_name = "Roundtrip Test"
	c.character_class = GameConstants.CharacterClass.KNIGHT
	c.level = 7
	c.experience = 42
	c.current_hp = 18
	c.max_hp = 33
	c.attack = 11
	c.defense = 9
	c.speed = 6
	c.leadership = 8
	c.weapon_type = "axe"
	c.soldiers = 77
	c.max_soldiers = 88
	c.faction = "nifl"
	c.sprite_frames_path = "res://assets/characters/char_01_alm/"

	var skill = SkillData.new()
	skill.skill_name = "Test Skill"
	skill.description = "desc"
	skill.skill_type = SkillData.SkillType.PASSIVE
	skill.target_type = SkillData.TargetType.SELF
	skill.power = 42
	skill.cooldown = 5
	skill.current_cooldown = 1
	c.skills.append(skill)

	c.tactics.clear()
	var tactic = Tactic.new()
	tactic.priority = 3
	tactic.condition_type = Tactic.ConditionType.ENEMY_HP_LOW
	tactic.condition_value = 0.25
	tactic.target_type = Tactic.TargetType.LOWEST_HP
	tactic.action_type = Tactic.ActionType.DEFEND
	tactic.use_skill = true
	c.tactics.append(tactic)
	return c

func _check_character_matches(restored: CharacterData, prefix: String):
	check(restored.character_name == "Roundtrip Test", prefix + ": name")
	check(restored.character_class == GameConstants.CharacterClass.KNIGHT, prefix + ": class")
	check(restored.level == 7, prefix + ": level")
	check(restored.experience == 42, prefix + ": experience")
	check(restored.current_hp == 18, prefix + ": current_hp")
	check(restored.max_hp == 33, prefix + ": max_hp")
	check(restored.attack == 11, prefix + ": attack")
	check(restored.defense == 9, prefix + ": defense")
	check(restored.speed == 6, prefix + ": speed")
	check(restored.leadership == 8, prefix + ": leadership")
	check(restored.weapon_type == "axe", prefix + ": weapon_type")
	check(restored.soldiers == 77, prefix + ": soldiers")
	check(restored.max_soldiers == 88, prefix + ": max_soldiers")
	check(restored.faction == "nifl", prefix + ": faction")
	check(restored.sprite_frames_path == "res://assets/characters/char_01_alm/", prefix + ": sprite_frames_path")
	check(restored.skills.size() == 1, prefix + ": one skill")
	if restored.skills.size() == 1:
		var s = restored.skills[0]
		check(s.skill_name == "Test Skill" and s.power == 42 and s.cooldown == 5 \
			and s.current_cooldown == 1 and s.skill_type == SkillData.SkillType.PASSIVE \
			and s.target_type == SkillData.TargetType.SELF and s.description == "desc", prefix + ": skill fields")
	check(restored.tactics.size() == 1, prefix + ": one tactic")
	if restored.tactics.size() == 1:
		var t = restored.tactics[0]
		check(t.priority == 3 and t.condition_type == Tactic.ConditionType.ENEMY_HP_LOW \
			and abs(t.condition_value - 0.25) < 0.001 and t.target_type == Tactic.TargetType.LOWEST_HP \
			and t.action_type == Tactic.ActionType.DEFEND and t.use_skill == true, prefix + ": tactic fields")

func _run():
	# --- 1. CharacterData round-trip through actual JSON ---
	var original = _make_character()
	var json_text = JSON.stringify(original.to_dict())
	var json = JSON.new()
	check(json.parse(json_text) == OK, "to_dict output is valid JSON")
	var restored = CharacterData.from_dict(json.data)
	_check_character_matches(restored, "roundtrip")

	# --- 2. Defaults when fields are absent ---
	var bare = CharacterData.from_dict({"name": "Bare"}, "fallback_faction")
	check(bare.character_name == "Bare", "defaults: name")
	check(bare.tactics.size() == 4, "defaults: default tactics created when missing")
	check(bare.faction == "fallback_faction", "defaults: faction falls back to argument")
	check(bare.skills.is_empty(), "defaults: no skills")

	# --- 3. save_game / load_game round-trip (backing up any real save) ---
	var sm_script = load("res://scripts/autoload/SaveManager.gd")
	var save_path: String = sm_script.SAVE_PATH
	var backup = null
	if FileAccess.file_exists(save_path):
		var f = FileAccess.open(save_path, FileAccess.READ)
		backup = f.get_as_text()
		f.close()

	var gm = load("res://scripts/autoload/GameManager.gd").new()
	var sm = sm_script.new()
	sm.game_manager = gm
	gm.player_army.append(original)
	gm.current_chapter = 3
	gm.player_gold = 777
	gm.current_faction = "embla"
	sm.save_game()

	# Version field present in the written file
	var file = FileAccess.open(save_path, FileAccess.READ)
	var written = JSON.new()
	written.parse(file.get_as_text())
	file.close()
	check(written.data.get("version", 0) == 2, "savegame.json carries version 2")

	# Load into a fresh manager and compare
	var gm2 = load("res://scripts/autoload/GameManager.gd").new()
	var sm2 = sm_script.new()
	sm2.game_manager = gm2
	check(sm2.load_game(), "load_game returns true")
	check(gm2.current_chapter == 3, "loaded: chapter")
	check(gm2.player_gold == 777, "loaded: gold")
	check(gm2.current_faction == "embla", "loaded: faction")
	check(gm2.player_army.size() == 1, "loaded: one character")
	if gm2.player_army.size() == 1:
		_check_character_matches(gm2.player_army[0], "loaded")

	# Restore the previous save file (or remove the one the test created)
	if backup == null:
		DirAccess.remove_absolute(save_path)
	else:
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()

	gm.free()
	sm.free()
	gm2.free()
	sm2.free()

	print("---")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(failures)

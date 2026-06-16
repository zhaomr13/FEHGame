extends SceneTree

func _initialize():
	# In --script mode autoload singletons are not available at compile time,
	# so instantiate GameManager and SaveManager locally and wire them together.
	var gm = load("res://scripts/autoload/GameManager.gd").new()
	var sm = load("res://scripts/autoload/SaveManager.gd").new()
	sm.game_manager = gm

	gm._initialize_all_characters()
	gm.player_army = gm.all_characters.duplicate()
	gm.initialize_squads()

	_test_game_manager_squads(gm)
	_test_save_manager_v2(gm, sm)
	_test_save_manager_legacy_fallback(gm, sm)
	_test_squad_menu_data(gm)

	_cleanup_test_file(sm)

	print("Dynamic squad tests PASSED")
	quit(0)

func _cleanup_test_file(sm):
	if FileAccess.file_exists(sm.SQUAD_SAVE_PATH):
		DirAccess.remove_absolute(sm.SQUAD_SAVE_PATH)

func _test_game_manager_squads(gm):
	# Test 1: initialize_squads creates MAX_SQUADS empty squads
	gm.initialize_squads()
	assert(gm.squad_data.size() == GameConstants.MAX_SQUADS, "Expected %d squads, got %d" % [GameConstants.MAX_SQUADS, gm.squad_data.size()])
	for i in range(gm.squad_data.size()):
		assert(gm.squad_data[i].size() == 0, "Squad %d should be empty" % i)
	assert(gm.unassigned_units.size() == gm.player_army.size(), "All units should be unassigned")

	# Test 2: get_active_squads returns only non-empty squads
	gm.squad_data[0].append(gm.unassigned_units.pop_front())
	gm.squad_data[2].append(gm.unassigned_units.pop_front())
	var active = gm.get_active_squads()
	assert(active.size() == 2, "Expected 2 active squads, got %d" % active.size())

	# Test 3: get_active_squad_indices returns correct indices
	var indices = gm.get_active_squad_indices()
	assert(indices.size() == 2, "Expected 2 active indices, got %d" % indices.size())
	assert(indices.has(0), "Index 0 should be active")
	assert(indices.has(2), "Index 2 should be active")
	assert(not indices.has(1), "Index 1 should not be active")

	# Test 4: get_squad returns correct squad by index
	assert(gm.get_squad(0).size() == 1, "Squad 0 should have 1 member")
	assert(gm.get_squad(1).size() == 0, "Squad 1 should be empty")
	assert(gm.get_squad(99).size() == 0, "Invalid index should return empty array")

	# Test 5: create_squad adds a new empty squad
	gm.squad_data.resize(5)
	var initial_size = gm.squad_data.size()
	var new_index = gm.create_squad()
	assert(new_index == initial_size, "New squad index should be %d, got %d" % [initial_size, new_index])
	assert(gm.squad_data.size() == initial_size + 1, "Squad count should increase by 1")
	assert(gm.squad_data[new_index].size() == 0, "New squad should be empty")

	# Test 6: create_squad returns -1 when at max
	while gm.squad_data.size() < GameConstants.MAX_SQUADS:
		gm.create_squad()
	var overflow = gm.create_squad()
	assert(overflow == -1, "Expected -1 when at max squads, got %d" % overflow)

	# Test 7: disband_squad moves members to unassigned and clears squad
	var char_in_squad = gm.squad_data[0][0]
	var unassigned_before = gm.unassigned_units.size()
	var result = gm.disband_squad(0)
	assert(result == true, "disband_squad should return true")
	assert(gm.squad_data[0].size() == 0, "Squad 0 should be empty after disband")
	assert(gm.unassigned_units.size() == unassigned_before + 1, "Unassigned should increase by 1")
	assert(gm.unassigned_units.has(char_in_squad), "Disbanded character should be in unassigned")

	# Test 8: disband_squad returns false for invalid index
	assert(gm.disband_squad(-1) == false, "disband_squad(-1) should return false")
	assert(gm.disband_squad(999) == false, "disband_squad(999) should return false")

	# Test 9: remove_empty_squads compacts the array
	gm.squad_data[1].clear()
	gm.squad_data[3].clear()
	var before_remove = gm.squad_data.size()
	gm.remove_empty_squads()
	var after_remove = gm.squad_data.size()
	assert(after_remove < before_remove, "remove_empty_squads should reduce size")
	for squad in gm.squad_data:
		assert(squad.size() > 0, "All remaining squads should be non-empty")

	# Test 10: destroy_squad_after_defeat removes characters permanently
	gm.initialize_squads()
	gm.squad_data[0].append(gm.unassigned_units.pop_front())
	var victim = gm.squad_data[0][0]
	var army_before = gm.player_army.size()
	gm.destroy_squad_after_defeat(0)
	assert(gm.player_army.size() == army_before - 1, "Army should decrease by 1")
	assert(not gm.player_army.has(victim), "Victim should be removed from player_army")
	assert(not gm.unassigned_units.has(victim), "Victim should be removed from unassigned")

	# Test 11: get_squad_index_for_character
	gm.initialize_squads()
	var test_char = gm.unassigned_units[0]
	gm.squad_data[3].append(test_char)
	gm.unassigned_units.erase(test_char)
	assert(gm.get_squad_index_for_character(test_char) == 3, "Character should be in squad 3")
	assert(gm.get_squad_index_for_character(gm.unassigned_units[0]) == -1, "Unassigned character should return -1")

	# Test 12: update_squad_data works with dynamic squad count
	gm.initialize_squads()
	var new_squads = [[gm.unassigned_units[0]], [gm.unassigned_units[1]], [], [gm.unassigned_units[2]], []]
	var new_unassigned: Array[CharacterData] = []
	for i in range(3, gm.unassigned_units.size()):
		new_unassigned.append(gm.unassigned_units[i])
	gm.update_squad_data(new_squads, new_unassigned)
	assert(gm.squad_data.size() == 5, "update_squad_data should accept 5 squads")
	assert(gm.player_army.size() == gm.unassigned_units.size() + 3, "player_army should be rebuilt correctly")

func _test_save_manager_v2(gm, sm):
	gm.initialize_squads()
	var char1 = gm.unassigned_units.pop_front()
	var char2 = gm.unassigned_units.pop_front()
	gm.squad_data[0].append(char1)
	gm.squad_data[1].append(char2)

	var squads = gm.squad_data.duplicate(true)
	var unassigned = gm.unassigned_units.duplicate()

	# Save to the default squad save path and clean up afterward.
	sm.save_squads(squads, unassigned)

	# Reset squads/unassigned but keep player_army so names can be resolved
	gm.squad_data.clear()
	gm.unassigned_units.clear()

	var loaded_squads = sm.load_squads()
	var loaded_unassigned = sm.load_unassigned()

	if FileAccess.file_exists(sm.SQUAD_SAVE_PATH):
		DirAccess.remove_absolute(sm.SQUAD_SAVE_PATH)

	assert(loaded_squads.size() == GameConstants.MAX_SQUADS, "Loaded squads should be padded to MAX_SQUADS")
	assert(loaded_squads[0].size() == 1, "Squad 0 should have 1 member")
	assert(loaded_squads[1].size() == 1, "Squad 1 should have 1 member")
	assert(loaded_squads[0][0].character_name == char1.character_name, "Squad 0 member should match")
	assert(loaded_squads[1][0].character_name == char2.character_name, "Squad 1 member should match")
	assert(loaded_unassigned.size() == unassigned.size(), "Unassigned count should match")

	# Verify version field in saved file
	gm.squad_data = squads
	gm.unassigned_units = unassigned
	sm.save_squads(squads, unassigned)
	var file = FileAccess.open(sm.SQUAD_SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	json.parse(json_string)
	var data = json.data
	assert(data.get("version", 0) == 2, "Saved squad data should be version 2")
	assert(data["squads"] is Array and data["squads"].size() == GameConstants.MAX_SQUADS, "Saved squads should be dynamic array")

func _test_save_manager_legacy_fallback(gm, sm):
	# Write a legacy v1 format file to the default squad save path.
	var legacy_data = {
		"squads": [
			["Alfonse"],
			["Sharena"],
			[]
		],
		"unassigned": ["Anna"]
	}
	var file = FileAccess.open(sm.SQUAD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()

	# Ensure player_army has the referenced characters
	gm.player_army.clear()
	for name in ["Alfonse", "Sharena", "Anna"]:
		var cd = CharacterData.new()
		cd.character_name = name
		gm.player_army.append(cd)

	gm.squad_data.clear()
	gm.unassigned_units.clear()

	var loaded_squads = sm.load_squads()
	var loaded_unassigned = sm.load_unassigned()

	if FileAccess.file_exists(sm.SQUAD_SAVE_PATH):
		DirAccess.remove_absolute(sm.SQUAD_SAVE_PATH)

	assert(loaded_squads.size() == GameConstants.MAX_SQUADS, "Legacy load should pad to MAX_SQUADS")
	assert(loaded_squads[0].size() == 1 and loaded_squads[0][0].character_name == "Alfonse", "Legacy squad 0 should load Alfonse")
	assert(loaded_squads[1].size() == 1 and loaded_squads[1][0].character_name == "Sharena", "Legacy squad 1 should load Sharena")
	assert(loaded_unassigned.size() == 1 and loaded_unassigned[0].character_name == "Anna", "Legacy unassigned should load Anna")

func _test_squad_menu_data(gm):
	gm.initialize_squads()
	var data = SquadMenuData.new()
	data.game_manager = gm
	data.load_squad_data()

	assert(data.squads.size() == GameConstants.MAX_SQUADS, "SquadMenuData should load MAX_SQUADS squads")

	# Shrink to 5 squads so create_squad has room to test.
	data.squads.resize(5)

	# Move a character to a squad
	var test_char = gm.unassigned_units[0]
	data.select("unassigned", 0, test_char)
	var error = data.move_character_to_first_non_full_squad()
	assert(error == "", "move_character_to_first_non_full_squad should succeed")
	assert(data.squads[0].has(test_char), "Character should be in first squad")
	assert(not data.unassigned.has(test_char), "Character should no longer be unassigned")

	# Create a new squad
	var new_index = data.create_squad()
	assert(new_index == 5, "New squad should be appended at index 5")
	assert(data.squads.size() == 6, "Squad count should increase by 1")

	# Disband the squad containing the character
	data.select("squad_0", 0, test_char)
	assert(data.get_selected_squad_index() == 0, "Selected squad index should be 0")
	assert(data.disband_squad(0) == true, "disband_squad should succeed")
	assert(data.squads[0].size() == 0, "Squad 0 should be empty after disband")
	assert(data.unassigned.has(test_char), "Disbanded character should be unassigned")

	# Remove empty squads
	data.remove_empty_squads()
	assert(data.squads.size() < 6, "remove_empty_squads should compact")

	# Create a fresh squad to move into
	var fresh_index = data.create_squad()
	assert(fresh_index >= 0, "create_squad should succeed after compaction")

	# Move to specific squad
	var char2 = data.unassigned[0]
	data.select("unassigned", 0, char2)
	var move_error = data.move_character_to_squad(fresh_index)
	assert(move_error == "", "move_character_to_squad should succeed")
	assert(data.squads[fresh_index].has(char2), "Character should be in squad %d" % fresh_index)

	# Remove from squad
	var idx_in_squad = data.squads[fresh_index].find(char2)
	data.select("squad_%d" % fresh_index, idx_in_squad, char2)
	data.remove_from_squad()
	assert(not data.squads[fresh_index].has(char2), "Character should be removed from squad")
	assert(data.unassigned.has(char2), "Character should be unassigned after remove")

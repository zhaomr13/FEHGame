extends SceneTree

# Verifies Army.gd faction-icon behavior:
#  1. Empty faction -> no icon
#  2. set_faction creates the icon named exactly "FactionIcon"
#  3. Changing faction replaces the icon (no duplicates, name kept, texture updated)
#  4. update_visibility() hides/shows the icon when the army is in a city
#  5. Setting faction before _ready (add_child) still yields one correctly-named icon

var failures := 0

func check(cond: bool, msg: String):
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize():
	call_deferred("_run")

func _count_icon_children(army: Army) -> int:
	var count := 0
	for c in army.get_children():
		if c.name.begins_with("FactionIcon"):
			count += 1
	return count

func _run():
	# --- Scenario A: faction set after _ready (all current call sites) ---
	var army = Army.new()
	root.add_child(army)  # _ready runs with faction ""
	check(army.get_node_or_null("FactionIcon") == null, "A1: no icon while faction is empty")

	army.faction = "askr"
	var icon = army.get_node_or_null("FactionIcon")
	check(icon != null, "A2: icon created after set_faction")
	if icon:
		check(icon.name == "FactionIcon", "A3: icon is named FactionIcon (got '%s')" % icon.name)
		check(icon.texture == GameConstants.get_faction_icon("askr"), "A4: icon texture matches askr")

	army.faction = "embla"  # change again: old icon queue_free'd, new one added same frame
	await process_frame
	check(_count_icon_children(army) == 1, "A5: exactly one icon after faction change (got %d)" % _count_icon_children(army))
	var icon2 = army.get_node_or_null("FactionIcon")
	check(icon2 != null, "A6: get_node('FactionIcon') still resolves after change")
	if icon2:
		check(icon2.texture == GameConstants.get_faction_icon("embla"), "A7: icon texture updated to embla")

	# Visibility toggling must find the icon by name
	army.current_city_id = "city_01"
	army.update_visibility()
	var icon3 = army.get_node_or_null("FactionIcon")
	check(icon3 != null and not icon3.visible, "A8: icon hidden while army is in a city")
	army.current_city_id = ""
	army.update_visibility()
	var icon4 = army.get_node_or_null("FactionIcon")
	check(icon4 != null and icon4.visible, "A9: icon visible again when army leaves the city")

	army.queue_free()
	await process_frame

	# --- Scenario B: faction set BEFORE _ready (future-proofing) ---
	var army2 = Army.new()
	army2.faction = "nifl"
	root.add_child(army2)  # _ready -> setup_visual -> _update_faction_icon again
	await process_frame
	check(_count_icon_children(army2) == 1, "B1: exactly one icon when faction set before _ready (got %d)" % _count_icon_children(army2))
	var iconB = army2.get_node_or_null("FactionIcon")
	check(iconB != null, "B2: get_node('FactionIcon') resolves in scenario B")
	if iconB:
		check(iconB.texture == GameConstants.get_faction_icon("nifl"), "B3: icon texture matches nifl")
	army2.current_city_id = "city_02"
	army2.update_visibility()
	var iconB2 = army2.get_node_or_null("FactionIcon")
	check(iconB2 != null and not iconB2.visible, "B4: icon hidden in city in scenario B")

	print("---")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(failures)

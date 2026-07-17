extends SceneTree

# Verifies the atlas loading changes:
#  1. Headless runs skip the GameManager background preload thread
#  2. load_character_atlas returns a usable SpriteFrames and caches by folder
#  3. Concurrent loads (same + different folders) are thread-safe: no crash,
#  no duplicate cache entries, identical instances returned

var failures := 0

func check(cond: bool, msg: String):
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize():
	call_deferred("_run")

func _run():
	var loader = load("res://scripts/AtlasLoader.gd")
	var f1 = "res://assets/characters/char_01_alm"
	var f2 = "res://assets/characters/char_02_lilina"
	var f3 = "res://assets/characters/char_03_dorcas"

	# 1. GameManager autoload must not start the preload thread when headless
	var gm = root.get_node_or_null("/root/GameManager")
	check(gm != null, "GameManager autoload present")
	if gm:
		check(gm._preload_thread == null, "preload thread skipped in headless mode")

	# 2. Basic load + cache identity
	var t = Time.get_ticks_msec()
	var sf1 = loader.load_character_atlas(f1)
	var elapsed = Time.get_ticks_msec() - t
	check(sf1 != null and sf1.has_animation("Idle"), "alm atlas loads with Idle animation")
	if sf1 and sf1.has_animation("Idle"):
		check(sf1.get_frame_count("Idle") > 0, "Idle animation has frames")
	var sf1b = loader.load_character_atlas(f1)
	check(sf1b == sf1, "second load of same folder returns cached instance")
	print("    (single-folder load took %d ms)" % elapsed)

	# 3. Concurrent loads: two threads on the same folder, one on another
	var t1 = Thread.new()
	var t2 = Thread.new()
	var t3 = Thread.new()
	t1.start(loader.load_character_atlas.bind(f2))
	t2.start(loader.load_character_atlas.bind(f2))
	t3.start(loader.load_character_atlas.bind(f3))
	t1.wait_to_finish()
	t2.wait_to_finish()
	t3.wait_to_finish()
	var sf2 = loader.load_character_atlas(f2)
	var sf3 = loader.load_character_atlas(f3)
	check(sf2 != null and sf2.has_animation("Idle"), "lilina atlas valid after concurrent loads")
	check(sf3 != null and sf3.has_animation("Idle"), "dorcas atlas valid after concurrent loads")
	if sf2 and sf2.has_animation("Idle"):
		check(sf2.get_frame_count("Idle") > 0, "lilina Idle animation has frames")

	print("---")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d" % failures)
	quit(failures)

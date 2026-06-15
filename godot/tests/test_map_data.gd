extends SceneTree

func _initialize():
    var mgr_script = load("res://scripts/world_map/MapDataManager.gd")
    var mgr = mgr_script.new()
    root.add_child(mgr)

    await create_timer(0.01).timeout

    var config = mgr.NODE_CONFIG
    assert(config != null and not config.is_empty(), "NODE_CONFIG should not be empty")
    assert(config.size() >= 75 and config.size() <= 85, "Node count should be ~80, got %d" % config.size())

    var valid = mgr.validate_map_data()
    assert(valid, "Map data validation failed; check output for warnings")

    print("Map data test PASSED: %d nodes, fully connected, no overlaps" % config.size())
    quit(0)

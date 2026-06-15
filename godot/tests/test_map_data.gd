extends SceneTree

func _initialize():
    var mgr_script = load("res://scripts/world_map/MapDataManager.gd")
    assert(mgr_script != null, "Failed to load MapDataManager script")

    var mgr = mgr_script.new()
    mgr.map_data_loaded.connect(_on_map_data_loaded.bind(mgr))
    root.add_child(mgr)

func _on_map_data_loaded(success: bool, mgr):
    assert(success, "Map data failed to load")

    var config = mgr.NODE_CONFIG
    assert(config != null and not config.is_empty(), "NODE_CONFIG should not be empty")

    var expected_count = _count_nodes_in_json()
    assert(config.size() == expected_count, "Expected %d nodes, got %d" % [expected_count, config.size()])

    assert(mgr.validate_map_data(), "Map data validation failed")

    # Sanity-check gameplay helpers
    assert(mgr.can_move_to("city_01", "city_07") or mgr.can_move_to("city_01", "city_04"), "Expected city_01 to connect to a neighbor")
    var path = mgr.find_path("city_01", "city_45")
    assert(not path.is_empty(), "Expected a path from city_01 to city_45")

    print("Map data test PASSED: %d nodes, fully connected, no overlaps" % config.size())
    quit(0)

func _count_nodes_in_json() -> int:
    var json_text = FileAccess.get_file_as_string("res://data/world_map.json")
    var parsed = JSON.parse_string(json_text)
    assert(parsed is Dictionary, "Failed to parse world_map.json")
    return parsed["nodes"].size()

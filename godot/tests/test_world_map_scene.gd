extends SceneTree

func _initialize():
    # Test 1: Verify WorldMap.tscn structure by parsing the scene file
    var tscn_path = "res://scenes/world_map/WorldMap.tscn"
    var tscn_text = FileAccess.get_file_as_string(tscn_path)
    assert(not tscn_text.is_empty(), "Failed to read WorldMap.tscn")

    # Check key nodes exist in the scene file
    assert(tscn_text.contains("[node name=\"WorldMap\" type=\"Node2D\"]"), "Root WorldMap node not found")
    assert(tscn_text.contains("[node name=\"Camera2D\" type=\"Camera2D\" parent=\".\"]"), "Camera2D not found")
    assert(tscn_text.contains("[node name=\"Background\" type=\"Sprite2D\" parent=\".\"]"), "Background not found")
    assert(tscn_text.contains("[node name=\"MapDataManager\" type=\"Node2D\" parent=\".\"]"), "MapDataManager not found")
    assert(tscn_text.contains("[node name=\"MapNodes\" type=\"Node2D\" parent=\".\"]"), "MapNodes container not found")
    assert(tscn_text.contains("[node name=\"Connections\" type=\"Node2D\" parent=\".\"]"), "Connections container not found")
    assert(tscn_text.contains("[node name=\"Armies\" type=\"Node2D\" parent=\".\"]"), "Armies container not found")
    assert(tscn_text.contains("[node name=\"WorldMapUI\" type=\"CanvasLayer\" parent=\".\"]"), "WorldMapUI not found")

    # Check background node exists (texture is now generated programmatically as black)
    assert(tscn_text.contains("[node name=\"Background\" type=\"Sprite2D\" parent=\".\"]"), "Background not found")

    # Check WorldMapManager script reference
    assert(tscn_text.contains("WorldMapManager.gd"), "WorldMapManager script not assigned")

    # Check MapDataManager script reference
    assert(tscn_text.contains("MapDataManager.gd"), "MapDataManager script not assigned")

    # Test 2: Verify MapDataManager loads 80 nodes (same as test_map_data.gd)
    var mgr_script = load("res://scripts/world_map/MapDataManager.gd")
    assert(mgr_script != null, "Failed to load MapDataManager script")

    var mgr = mgr_script.new()
    mgr.map_data_loaded.connect(_on_map_data_loaded.bind(mgr))
    root.add_child(mgr)

func _on_map_data_loaded(success: bool, mgr):
    assert(success, "Map data failed to load")

    var config = mgr.NODE_CONFIG
    assert(config != null and not config.is_empty(), "NODE_CONFIG should not be empty")
    assert(config.size() == 80, "Expected 80 nodes, got %d" % config.size())

    assert(mgr.validate_map_data(), "Map data validation failed")

    # Test 3: Verify world_map.yaml has 80 nodes
    var yaml_text = FileAccess.get_file_as_string("res://data/world_map.yaml")
    var parser_script = load("res://scripts/utils/YamlParser.gd")
    var parser = parser_script.new()
    var parsed = parser.parse(yaml_text)
    assert(parsed is Dictionary, "Failed to parse world_map.yaml")
    var node_count = parsed["nodes"].size()
    assert(node_count == 80, "Expected 80 nodes in YAML, got %d" % node_count)

    print("WorldMap scene integration test PASSED")
    _test_army_visibility()
    quit(0)

func _test_army_visibility():
    var ArmyScript = load("res://scripts/world_map/Army.gd")
    var army = ArmyScript.new()
    army.current_city_id = "city_1"
    army.state = ArmyScript.ArmyState.IDLE
    army._ready()
    assert(not army.get_node("CirclePanel").visible, "Idle army in city should hide body")

    army.state = ArmyScript.ArmyState.PLANNED
    army.update_visibility()
    assert(not army.get_node("CirclePanel").visible, "Planned army still in city should hide body")

    army.state = ArmyScript.ArmyState.MOVING
    army.update_visibility()
    assert(army.get_node("CirclePanel").visible, "Moving army should show body")

    army.state = ArmyScript.ArmyState.IDLE
    army.current_city_id = ""
    army.update_visibility()
    assert(army.get_node("CirclePanel").visible, "Idle army not in a city should show body")

    print("Army visibility test PASSED")

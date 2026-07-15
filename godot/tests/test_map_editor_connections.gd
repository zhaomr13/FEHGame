extends SceneTree

func _initialize():
    var editor_script = load("res://scripts/editor/MapEditor.gd")
    assert(editor_script != null, "Failed to load MapEditor script")

    var editor = editor_script.new()
    editor.connections_node = Node2D.new()
    editor._city_nodes = {}

    var city1_data := {
        "id": "city_01",
        "name": "City One",
        "type": "city",
        "pos": {"x": 100, "y": 100},
        "faction": "",
        "force_connections": []
    }
    var city2_data := {
        "id": "city_02",
        "name": "City Two",
        "type": "city",
        "pos": {"x": 200, "y": 200},
        "faction": "",
        "force_connections": []
    }

    editor._cities.assign([city1_data, city2_data])

    var city_script = load("res://scripts/editor/MapEditorCity.gd")
    assert(city_script != null, "Failed to load MapEditorCity script")

    var city1 = city_script.new()
    city1.setup(city1_data)
    editor._city_nodes["city_01"] = city1

    var city2 = city_script.new()
    city2.setup(city2_data)
    editor._city_nodes["city_02"] = city2

    editor._selected_city = city1

    editor._on_connection_toggled("city_02", true)

    var conns1: Array = city1_data.get("force_connections", []) as Array
    var conns2: Array = city2_data.get("force_connections", []) as Array

    var has_1_to_2: bool = conns1.has("city_02")
    var has_2_to_1: bool = conns2.has("city_01")
    assert(has_1_to_2 == bool(true), "city_01 should connect to city_02")
    assert(has_2_to_1 == bool(true), "city_02 should connect to city_01")

    editor._on_connection_toggled("city_02", false)

    conns1 = city1_data.get("force_connections", []) as Array
    conns2 = city2_data.get("force_connections", []) as Array

    has_1_to_2 = conns1.has("city_02")
    has_2_to_1 = conns2.has("city_01")
    assert(has_1_to_2 == bool(false), "city_01 should not connect to city_02")
    assert(has_2_to_1 == bool(false), "city_02 should not connect to city_01")

    print("Map editor connection test PASSED")
    quit(0)

extends SceneTree

func _initialize():
    var parser_script = load("res://scripts/utils/YamlParser.gd")
    assert(parser_script != null, "Failed to load YamlParser")

    var parser = parser_script.new()

    # NOTE: the parser requires documents to start at column 0 (indented
    # top-level lines are skipped), so these YAML strings are flush-left.
    # Test 1: Basic key-value parsing
    var yaml1 = """
name: "Test"
level: 5
alive: true
"""
    var result1 = parser.parse(yaml1)
    assert(result1 is Dictionary, "Parser should return Dictionary")
    assert(result1.get("name") == "Test", "Name should be 'Test'")
    assert(result1.get("level") == 5, "Level should be 5")
    assert(result1.get("alive") == true, "Alive should be true")

    # Test 2: List of scalars
    var yaml2 = """
factions:
  - askr
  - embla
  - nifl
"""
    var result2 = parser.parse(yaml2)
    var factions = result2.get("factions", [])
    assert(factions is Array, "factions should be an Array")
    assert(factions.size() == 3, "Expected 3 factions")
    assert(factions[0] == "askr", "First faction should be askr")
    assert(factions[1] == "embla", "Second faction should be embla")
    assert(factions[2] == "nifl", "Third faction should be nifl")

    # Test 3: List of dictionaries (character database shape)
    var yaml3 = """
characters:
  - name: "Sharena"
    class: "KNIGHT"
    max_hp: 30
  - name: "Alfonse"
    class: "LORD"
    max_hp: 25
"""
    var result3 = parser.parse(yaml3)
    var chars = result3.get("characters", [])
    assert(chars is Array, "characters should be an Array")
    assert(chars.size() == 2, "Expected 2 characters")
    assert(chars[0].get("name") == "Sharena", "First character name should be Sharena")
    assert(chars[0].get("class") == "KNIGHT", "First character class should be KNIGHT")
    assert(chars[0].get("max_hp") == 30, "First character max_hp should be 30")
    assert(chars[1].get("name") == "Alfonse", "Second character name should be Alfonse")
    assert(chars[1].get("class") == "LORD", "Second character class should be LORD")
    assert(chars[1].get("max_hp") == 25, "Second character max_hp should be 25")

    # Test 4: Comments
    var yaml4 = """
# This is a comment
key: value
# Another comment
list:
  - item1
  - item2
"""
    var result4 = parser.parse(yaml4)
    assert(result4.get("key") == "value", "Should parse key despite comments")
    assert(result4.get("list", []).size() == 2, "Should parse list despite comments")

    # Test 5: Nested dictionary
    var yaml5 = """
root:
  child:
    grandchild: 42
"""
    var result5 = parser.parse(yaml5)
    var root = result5.get("root", {})
    assert(root is Dictionary, "root should be Dictionary")
    assert(root.get("child", {}).get("grandchild") == 42, "Nested grandchild should be 42")

    print("YamlParser test PASSED")
    quit(0)

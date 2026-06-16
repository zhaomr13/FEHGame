extends SceneTree

func _initialize():
    var generator_script = load("res://scripts/character/CharacterGenerator.gd")
    assert(generator_script != null, "Failed to load CharacterGenerator script")

    var generator = generator_script.new()
    assert(generator != null, "Failed to instantiate CharacterGenerator")

    var roster = generator.generate_roster(10)
    assert(roster.size() == 10, "Expected 10 generated characters, got %d" % roster.size())

    var names = {}
    for char in roster:
        assert(char is CharacterData, "Generated item is not CharacterData")
        assert(char.character_name != "", "Character has empty name")
        assert(not names.has(char.character_name), "Duplicate name: %s" % char.character_name)
        names[char.character_name] = true

    print("CharacterGenerator skeleton test PASSED")
    quit(0)

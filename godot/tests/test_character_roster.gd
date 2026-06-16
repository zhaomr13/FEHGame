extends SceneTree

func _initialize():
    var generator_script = load("res://scripts/character/CharacterGenerator.gd")
    assert(generator_script != null, "Failed to load CharacterGenerator script")

    var generator = generator_script.new()
    assert(generator != null, "Failed to instantiate CharacterGenerator")

    var roster = generator.generate_roster(10)
    assert(roster.size() == 10, "Expected 10 generated characters, got %d" % roster.size())

    var names = {}
    for character in roster:
        assert(character is CharacterData, "Generated item is not CharacterData")
        assert(character.character_name != "", "Character has empty name")
        assert(not names.has(character.character_name), "Duplicate name: %s" % character.character_name)
        names[character.character_name] = true

    # Name uniqueness and style check
    var roster100 = generator.generate_roster(100)
    var names100 = {}
    for char in roster100:
        assert(not names100.has(char.character_name), "Duplicate name in 100 roster: %s" % char.character_name)
        names100[char.character_name] = true
        assert(char.character_name.length() >= 2, "Name too short: %s" % char.character_name)
        assert(not char.character_name.begins_with("Test"), "Name should not be skeleton placeholder: %s" % char.character_name)

    print("CharacterGenerator skeleton test PASSED")
    quit(0)

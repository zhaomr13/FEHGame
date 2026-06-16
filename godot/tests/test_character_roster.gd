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
        assert(not char.character_name.begins_with("Test"), "Name should not begin with 'Test': %s" % char.character_name)

    # Stat sanity check
    var sample = generator.generate_roster(20)
    for char in sample:
        assert(char.max_hp > 0, "HP must be positive")
        assert(char.attack > 0, "Attack must be positive")
        assert(char.defense >= 0, "Defense must be non-negative")
        assert(char.speed > 0, "Speed must be positive")
        assert(char.soldiers > 0, "Soldiers must be positive")
        assert(char.character_class in [
            GameConstants.CharacterClass.LORD,
            GameConstants.CharacterClass.KNIGHT,
            GameConstants.CharacterClass.MAGE,
            GameConstants.CharacterClass.FIGHTER,
            GameConstants.CharacterClass.ARCHER
        ], "Invalid character class")

    for char in sample:
        var template = generator.CLASS_TEMPLATES[char.character_class]
        assert(char.max_hp >= template.max_hp - generator.HP_VARIANCE and char.max_hp <= template.max_hp + generator.HP_VARIANCE,
            "HP %d out of variance range for %s" % [char.max_hp, char.character_class])
        assert(char.attack >= template.attack - generator.STAT_VARIANCE and char.attack <= template.attack + generator.STAT_VARIANCE,
            "Attack %d out of variance range for %s" % [char.attack, char.character_class])
        assert(char.defense >= template.defense - generator.STAT_VARIANCE and char.defense <= template.defense + generator.STAT_VARIANCE,
            "Defense %d out of variance range for %s" % [char.defense, char.character_class])
        assert(char.speed >= template.speed - generator.STAT_VARIANCE and char.speed <= template.speed + generator.STAT_VARIANCE,
            "Speed %d out of variance range for %s" % [char.speed, char.character_class])
        assert(char.soldiers >= template.soldiers - generator.SOLDIER_VARIANCE and char.soldiers <= template.soldiers + generator.SOLDIER_VARIANCE,
            "Soldiers %d out of variance range for %s" % [char.soldiers, char.character_class])
        assert(char.weapon_type == template.weapon,
            "Weapon type %s does not match class %s" % [char.weapon_type, char.character_class])
        assert(char.max_soldiers == char.soldiers,
            "max_soldiers %d does not match soldiers %d" % [char.max_soldiers, char.soldiers])
        assert(char.leadership >= generator.LEADERSHIP_MIN and char.leadership <= generator.LEADERSHIP_MAX,
            "Leadership %d out of range" % char.leadership)

    # Faction and sprite check
    var roster100b = generator.generate_roster(100)
    var faction_counts = {"askr": 0, "embla": 0, "nifl": 0, "muspell": 0}
    for char in roster100b:
        assert(faction_counts.has(char.faction), "Unexpected faction: %s" % char.faction)
        faction_counts[char.faction] += 1
        assert(char.sprite_frames_path != "", "Missing sprite path")
        var dir_access = DirAccess.open(char.sprite_frames_path.get_base_dir())
        assert(dir_access != null and dir_access.dir_exists(char.sprite_frames_path), "Sprite folder does not exist: %s" % char.sprite_frames_path)

    for faction in faction_counts.keys():
        var c = faction_counts[faction]
        assert(c >= 20 and c <= 30, "Faction %s count %d is out of balance" % [faction, c])

    print("CharacterGenerator test PASSED")
    quit(0)

extends SceneTree

func _initialize():
    # Test 1: Load CharacterDatabase
    var db_script = load("res://scripts/character/CharacterDatabase.gd")
    assert(db_script != null, "Failed to load CharacterDatabase script")

    var db = db_script.new()
    assert(db != null, "Failed to instantiate CharacterDatabase")

    # Test 2: Load all characters from YAML
    var characters = db.load_all_characters()
    assert(characters.size() == 115, "Expected 115 characters, got %d" % characters.size())

    # Test 3: Name uniqueness
    var names = {}
    for char in characters:
        assert(not names.has(char.character_name), "Duplicate name: %s" % char.character_name)
        names[char.character_name] = true

    # Test 4: Story characters exist with correct factions
    var expected_story = {
        "Sharena": "askr",
        "Alfonse": "askr",
        "Anna": "askr",
        "Veronica": "embla",
        "Bruno": "embla",
        "Loki": "embla",
        "Gunnthra": "nifl",
        "Hrid": "nifl",
        "Ylgr": "nifl",
        "Laevatein": "muspell",
        "Laegjarn": "muspell",
        "Helbindi": "muspell",
        "Klein": "",
        "Rebecca": "",
        "Lyn": ""
    }
    for char in characters:
        if expected_story.has(char.character_name):
            assert(char.faction == expected_story[char.character_name],
                "Story character %s has wrong faction: %s" % [char.character_name, char.faction])

    # Test 5: Stat sanity checks
    for char in characters:
        assert(char.max_hp > 0, "HP must be positive for %s" % char.character_name)
        assert(char.attack > 0, "Attack must be positive for %s" % char.character_name)
        assert(char.defense >= 0, "Defense must be non-negative for %s" % char.character_name)
        assert(char.speed > 0, "Speed must be positive for %s" % char.character_name)
        assert(char.soldiers > 0, "Soldiers must be positive for %s" % char.character_name)
        assert(char.character_class in [
            GameConstants.CharacterClass.LORD,
            GameConstants.CharacterClass.KNIGHT,
            GameConstants.CharacterClass.MAGE,
            GameConstants.CharacterClass.FIGHTER,
            GameConstants.CharacterClass.ARCHER
        ], "Invalid character class for %s" % char.character_name)

    # Test 6: Faction balance for generated characters
    var faction_counts = {"askr": 0, "embla": 0, "nifl": 0, "muspell": 0, "": 0}
    for char in characters:
        if faction_counts.has(char.faction):
            faction_counts[char.faction] += 1

    assert(faction_counts["askr"] >= 25, "Expected at least 25 askr characters, got %d" % faction_counts["askr"])
    assert(faction_counts["embla"] >= 25, "Expected at least 25 embla characters, got %d" % faction_counts["embla"])
    assert(faction_counts["nifl"] >= 25, "Expected at least 25 nifl characters, got %d" % faction_counts["nifl"])
    assert(faction_counts["muspell"] >= 25, "Expected at least 25 muspell characters, got %d" % faction_counts["muspell"])

    # Test 7: Sprite paths exist
    for char in characters:
        assert(char.sprite_frames_path != "", "Missing sprite path for %s" % char.character_name)
        var dir = DirAccess.open(char.sprite_frames_path.get_base_dir())
        assert(dir != null, "Sprite folder does not exist for %s: %s" % [char.character_name, char.sprite_frames_path])

    # Test 8: Tactics are set up
    for char in characters:
        assert(char.tactics.size() == 4, "Expected 4 tactics for %s, got %d" % [char.character_name, char.tactics.size()])

    # Test 9: Integration - GameManager loads all characters
    var gm = load("res://scripts/autoload/GameManager.gd").new()
    gm._initialize_all_characters()
    assert(gm.all_characters.size() == 115, "Expected 115 total characters in GameManager, got %d" % gm.all_characters.size())

    print("Character database test PASSED")
    quit(0)

extends Node

const SAVE_PATH = "user://savegame.json"
const SQUAD_SAVE_PATH = "user://squads.json"

func save_game():
    var save_data = {
        "chapter": GameManager.current_chapter,
        "gold": GameManager.player_gold,
        "player_army": []
    }

    for character in GameManager.player_army:
        save_data["player_army"].append({
            "name": character.character_name,
            "class": character.character_class,
            "level": character.level,
            "exp": character.experience,
            "hp": character.current_hp,
            "max_hp": character.max_hp,
            "attack": character.attack,
            "defense": character.defense,
            "speed": character.speed,
            "soldiers": character.soldiers
        })

    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    file.close()
    print("Game saved to ", SAVE_PATH)

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        print("No save file found")
        return false

    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        print("JSON parse error: ", json.get_error_message())
        return false

    var save_data = json.data
    GameManager.current_chapter = save_data.get("chapter", 1)
    GameManager.player_gold = save_data.get("gold", 1000)

    # Restore player army from save data
    GameManager.player_army.clear()
    var army_data = save_data.get("player_army", [])
    for char_data in army_data:
        var character = CharacterData.new()
        character.character_name = char_data.get("name", "Unknown")
        character.character_class = char_data.get("class", GameConstants.CharacterClass.LORD)
        character.level = char_data.get("level", 1)
        character.experience = char_data.get("exp", 0)
        character.current_hp = char_data.get("hp", 20)
        character.max_hp = char_data.get("max_hp", 20)
        character.attack = char_data.get("attack", 5)
        character.defense = char_data.get("defense", 3)
        character.speed = char_data.get("speed", 5)
        character.soldiers = char_data.get("soldiers", 100)
        character.setup_default_tactics()
        GameManager.player_army.append(character)

    # Load squad configuration
    if has_saved_squads():
        GameManager.squad_data = load_squads()
        GameManager.unassigned_units = load_unassigned()
    else:
        GameManager.initialize_squads()

    print("Game loaded from ", SAVE_PATH)
    return true

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

# Squad save/load functions
func save_squads(squads: Array, unassigned: Array[CharacterData]):
    """Save squad configuration to file"""
    var squad_save = {
        "squads": [[], [], []],
        "unassigned": []
    }

    # Save squad member names (to reference back to player_army)
    for i in range(3):
        for character in squads[i]:
            squad_save["squads"][i].append(character.character_name)

    for character in unassigned:
        squad_save["unassigned"].append(character.character_name)

    var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(squad_save))
    file.close()
    print("Squad configuration saved")

func load_squads() -> Array:
    """Load squad configuration from file"""
    if not FileAccess.file_exists(SQUAD_SAVE_PATH):
        return [[], [], []]

    var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        print("Squad JSON parse error: ", json.get_error_message())
        return [[], [], []]

    var squad_save = json.data
    var loaded_squads: Array = [[], [], []]

    # Restore squad references from player_army
    var character_lookup = {}
    for character in GameManager.player_army:
        character_lookup[character.character_name] = character

    for i in range(3):
        var squad_names = squad_save["squads"][i]
        for name in squad_names:
            if character_lookup.has(name):
                loaded_squads[i].append(character_lookup[name])

    return loaded_squads

func load_unassigned() -> Array[CharacterData]:
    """Load unassigned characters from file"""
    if not FileAccess.file_exists(SQUAD_SAVE_PATH):
        return []

    var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        return []

    var squad_save = json.data
    var loaded_unassigned: Array[CharacterData] = []

    # Restore unassigned references from player_army
    var character_lookup = {}
    for character in GameManager.player_army:
        character_lookup[character.character_name] = character

    var unassigned_names = squad_save.get("unassigned", [])
    for name in unassigned_names:
        if character_lookup.has(name):
            loaded_unassigned.append(character_lookup[name])

    return loaded_unassigned

func has_saved_squads() -> bool:
    """Check if squad configuration exists"""
    return FileAccess.file_exists(SQUAD_SAVE_PATH)

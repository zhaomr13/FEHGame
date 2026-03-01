extends Node

const SAVE_PATH = "user://savegame.json"

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

    # TODO: Restore player army from save data
    print("Game loaded from ", SAVE_PATH)
    return true

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

extends Node

signal state_changed(new_state: GameConstants.GameState)
signal battle_started(player_units: Array, enemy_units: Array)
signal battle_started_with_background(player_units: Array, enemy_units: Array, background_type: String)
signal battle_ended(victory: bool)

var current_state: GameConstants.GameState = GameConstants.GameState.MAIN_MENU
var player_army: Array[CharacterData] = []
var current_chapter: int = 1
var player_gold: int = 1000
var current_battle_background: String = "plain"
var current_faction: String = ""

# Squad system: 3 squads max, 6 characters per squad
# squad_data[0] = squad 1, squad_data[1] = squad 2, squad_data[2] = squad 3
var squad_data: Array = [[], [], []]
var unassigned_units: Array[CharacterData] = []

# All available characters in the game, assigned to factions
var all_characters: Array[CharacterData] = []
var available_recruits: Array[CharacterData] = []  # Characters that can be recruited

func _ready():
    print("GameManager initialized")
    _initialize_all_characters()

func _initialize_all_characters():
    """Initialize all characters in the game world with their faction affiliations"""
    all_characters.clear()

    # Askr Kingdom characters
    _create_character("Sharena", GameConstants.CharacterClass.KNIGHT, "askr", "lance", "char_02_lilina")
    _create_character("Alfonse", GameConstants.CharacterClass.LORD, "askr", "sword", "char_01_alm")
    _create_character("Anna", GameConstants.CharacterClass.FIGHTER, "askr", "axe", "char_08_robin")

    # Embla Empire characters
    _create_character("Veronica", GameConstants.CharacterClass.MAGE, "embla", "magic", "char_02_lilina")
    _create_character("Bruno", GameConstants.CharacterClass.LORD, "embla", "sword", "char_01_alm")
    _create_character("Loki", GameConstants.CharacterClass.ARCHER, "embla", "bow", "char_09_rebecca")

    # Nifl Kingdom characters
    _create_character("Gunnthra", GameConstants.CharacterClass.MAGE, "nifl", "magic", "char_02_lilina")
    _create_character("Hrid", GameConstants.CharacterClass.LORD, "nifl", "sword", "char_01_alm")
    _create_character("Ylgr", GameConstants.CharacterClass.FIGHTER, "nifl", "axe", "char_03_dorcas")

    # Muspell characters
    _create_character("Laevatein", GameConstants.CharacterClass.KNIGHT, "muspell", "sword", "char_10_hector")
    _create_character("Laegjarn", GameConstants.CharacterClass.KNIGHT, "muspell", "lance", "char_04_abel")
    _create_character("Helbindi", GameConstants.CharacterClass.FIGHTER, "muspell", "axe", "char_03_dorcas")

    # Neutral/Independent characters
    _create_character("Klein", GameConstants.CharacterClass.ARCHER, "", "bow", "char_05_klein")
    _create_character("Rebecca", GameConstants.CharacterClass.ARCHER, "", "bow", "char_09_rebecca")
    _create_character("Lyn", GameConstants.CharacterClass.LORD, "", "sword", "char_07_lyn")

func _create_character(name: String, char_class: GameConstants.CharacterClass, faction: String, weapon: String, sprite_folder: String):
    var char_data = CharacterData.new()
    char_data.character_name = name
    char_data.character_class = char_class
    char_data.faction = faction
    char_data.weapon_type = weapon
    char_data.sprite_frames_path = "res://assets/characters/" + sprite_folder + "/"
    char_data.setup_default_tactics()

    # Set stats based on class
    match char_class:
        GameConstants.CharacterClass.LORD:
            char_data.max_hp = 25
            char_data.attack = 8
            char_data.defense = 5
            char_data.speed = 6
        GameConstants.CharacterClass.KNIGHT:
            char_data.max_hp = 30
            char_data.attack = 7
            char_data.defense = 8
            char_data.speed = 4
        GameConstants.CharacterClass.FIGHTER:
            char_data.max_hp = 28
            char_data.attack = 9
            char_data.defense = 4
            char_data.speed = 5
        GameConstants.CharacterClass.MAGE:
            char_data.max_hp = 20
            char_data.attack = 10
            char_data.defense = 3
            char_data.speed = 6
        GameConstants.CharacterClass.ARCHER:
            char_data.max_hp = 22
            char_data.attack = 8
            char_data.defense = 4
            char_data.speed = 7

    char_data.current_hp = char_data.max_hp
    all_characters.append(char_data)

func get_characters_by_faction(faction: String) -> Array[CharacterData]:
    """Get all characters belonging to a specific faction"""
    var result: Array[CharacterData] = []
    for char in all_characters:
        if char.faction == faction:
            result.append(char)
    return result

func get_characters_not_in_faction(faction: String) -> Array[CharacterData]:
    """Get all characters NOT in the specified faction (for enemies)"""
    var result: Array[CharacterData] = []
    for char in all_characters:
        if char.faction != faction:
            result.append(char)
    return result

func recruit_character(character: CharacterData):
    """Recruit a character to player's army"""
    if not player_army.has(character):
        character.faction = current_faction if current_faction else "askr"
        player_army.append(character)
        available_recruits.erase(character)

func change_state(new_state: GameConstants.GameState):
    current_state = new_state
    state_changed.emit(new_state)
    print("State changed to: ", GameConstants.GameState.keys()[new_state])

func start_battle(player_units: Array, enemy_units: Array):
    battle_started.emit(player_units, enemy_units)
    change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)

func start_battle_with_background(player_units: Array, enemy_units: Array, background_type: String):
    current_battle_background = background_type
    battle_started_with_background.emit(player_units, enemy_units, background_type)

func end_battle(victory: bool):
    battle_ended.emit(victory)
    change_state(GameConstants.GameState.WORLD_MAP)

# Squad management functions
func initialize_squads():
    """Initialize squads from player_army - all unassigned"""
    squad_data = [[], [], []]
    unassigned_units = []
    for character in player_army:
        unassigned_units.append(character)

func get_active_squads() -> Array:
    """Return list of squads that have members"""
    var active = []
    for squad in squad_data:
        if squad.size() > 0:
            active.append(squad)
    return active

func get_squad(squad_index: int) -> Array:
    """Get a specific squad by index (0-2)"""
    if squad_index >= 0 and squad_index < squad_data.size():
        return squad_data[squad_index]
    return []

func update_squad_data(squads: Array, unassigned: Array[CharacterData]):
    """Update squad configuration from SquadMenu"""
    squad_data = squads
    unassigned_units = unassigned

    # Rebuild player_army in order (squad 1, 2, 3, unassigned)
    var new_army: Array[CharacterData] = []
    for squad in squad_data:
        for character in squad:
            new_army.append(character)
    for character in unassigned_units:
        new_army.append(character)
    player_army = new_army

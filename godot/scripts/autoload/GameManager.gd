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

# Squad system: dynamic squads, max 10 squads, 6 characters per squad
# squad_data is an Array of Arrays, each inner array is a squad's CharacterData[]
var squad_data: Array = []
var unassigned_units: Array[CharacterData] = []

# All available characters in the game, assigned to factions
var all_characters: Array[CharacterData] = []
var available_recruits: Array[CharacterData] = []  # Characters that can be recruited

func _ready():
    print("GameManager initialized")
    _initialize_all_characters()
    var t = Time.get_ticks_msec()
    var count = 0
    var done = {}
    for cd in all_characters:
        var folder = cd.sprite_frames_path.get_base_dir()
        if not done.has(folder):
            done[folder] = true
            preload("res://scripts/AtlasLoader.gd").load_character_atlas(folder)
            count += 1
    print("Preloaded ", count, " sprite atlases in ", Time.get_ticks_msec() - t, "ms")

func _initialize_all_characters():
    """Initialize all characters by loading them from the YAML database."""
    all_characters.clear()
    var db = CharacterDatabase.new()
    all_characters = db.load_all_characters()
    print("Loaded ", all_characters.size(), " characters from database")

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
    """Initialize squads from player_army - all unassigned, 10 empty squads"""
    squad_data = []
    for i in range(GameConstants.MAX_SQUADS):
        squad_data.append([])
    unassigned_units = []
    for character in player_army:
        unassigned_units.append(character)

func get_active_squads() -> Array:
    """Return list of squads that have members (non-empty)"""
    var active = []
    for squad in squad_data:
        if squad.size() > 0:
            active.append(squad)
    return active

func get_active_squad_indices() -> Array[int]:
    """Return indices of squads that have members"""
    var indices: Array[int] = []
    for i in range(squad_data.size()):
        if squad_data[i].size() > 0:
            indices.append(i)
    return indices

func get_squad(squad_index: int) -> Array:
    """Get a specific squad by index"""
    if squad_index >= 0 and squad_index < squad_data.size():
        return squad_data[squad_index]
    return []

func update_squad_data(squads: Array, unassigned: Array[CharacterData]):
    """Update squad configuration from SquadMenu"""
    squad_data = squads
    unassigned_units = unassigned

    # Rebuild player_army in order (squads, then unassigned)
    var new_army: Array[CharacterData] = []
    for squad in squad_data:
        for character in squad:
            new_army.append(character)
    for character in unassigned_units:
        new_army.append(character)
    player_army = new_army

func create_squad() -> int:
    """Create a new empty squad. Returns the new squad index, or -1 if at max."""
    if squad_data.size() >= GameConstants.MAX_SQUADS:
        return -1
    squad_data.append([])
    return squad_data.size() - 1

func disband_squad(squad_index: int) -> bool:
    """Disband a squad: all members become unassigned. Returns true if disbanded."""
    if squad_index < 0 or squad_index >= squad_data.size():
        return false
    var squad = squad_data[squad_index]
    for character in squad:
        if not unassigned_units.has(character):
            unassigned_units.append(character)
    squad_data[squad_index].clear()
    return true

func remove_empty_squads():
    """Remove all empty squads from the array, compacting indices."""
    var new_squads: Array = []
    for squad in squad_data:
        if squad.size() > 0:
            new_squads.append(squad)
    squad_data = new_squads

func destroy_squad_after_defeat(squad_index: int):
    """Permanently destroy a squad after battle defeat. Characters are removed from the game."""
    if squad_index < 0 or squad_index >= squad_data.size():
        return
    var squad = squad_data[squad_index]
    for character in squad:
        var idx = player_army.find(character)
        if idx >= 0:
            player_army.remove_at(idx)
        var uidx = unassigned_units.find(character)
        if uidx >= 0:
            unassigned_units.remove_at(uidx)
    squad_data[squad_index].clear()
    remove_empty_squads()

func get_squad_index_for_character(character: CharacterData) -> int:
    """Find which squad index a character belongs to, or -1 if unassigned/not found."""
    for i in range(squad_data.size()):
        if squad_data[i].has(character):
            return i
    return -1

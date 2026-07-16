class_name GameConstants

# Game States
enum GameState {
    MAIN_MENU,
    WORLD_MAP,
    BATTLE_DEPLOYMENT,
    BATTLE_ACTIVE,
    BATTLE_RESULT,
    GAME_OVER
}

# Map Node Types
enum NodeType {
    CITY,
    FORT,
    VILLAGE,
    EVENT,
    BATTLE
}

# Character Classes
enum CharacterClass {
    LORD,
    KNIGHT,
    MAGE,
    FIGHTER,
    ARCHER
}

# Formations
enum Formation {
    STANDARD,
    PHALANX,
    WEDGE,
    SKIRMISH,
    GUARD
}

# Display
const SCREEN_WIDTH = 1280
const SCREEN_HEIGHT = 720
const TILE_SIZE = 64

# Squad system
const MAX_SQUAD_SIZE: int = 6
const MAX_SQUADS: int = 20
const ARMIES_PER_FACTION: int = 10

const FACTION_ICONS = {
	"askr": preload("res://assets/ui/fraction1.png"),
	"embla": preload("res://assets/ui/fraction2.png"),
	"nifl": preload("res://assets/ui/fraction3.png"),
	"muspell": preload("res://assets/ui/fraction4.png")
}

static func get_faction_icon(faction: String) -> Texture2D:
	return FACTION_ICONS.get(faction, null)

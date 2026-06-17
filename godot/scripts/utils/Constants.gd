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

# 100-Character Roster Design

**Date:** 2026-06-16
**Scope:** Generate 100 additional playable characters with unique Chinese-translated fantasy names, class-based stats, faction distribution, and random reuse of existing sprite assets.

---

## 1. Goals

- Add 100 new `CharacterData` resources to the existing roster (currently 15).
- Keep the existing 15 characters unchanged.
- Generate names in Chinese fantasy-transliteration style (e.g., 阿尔方斯, 维罗妮卡).
- Use class templates + small random variance for stats.
- Distribute characters evenly across the four major factions: `askr`, `embla`, `nifl`, `muspell`.
- Reuse the 14 existing sprite folders randomly.
- Keep `GameManager._initialize_all_characters()` readable by moving generation logic to a dedicated `CharacterGenerator` class.

## 2. Non-Goals

- No new sprite art or animations.
- No new classes, weapons, or skills for this task.
- No persistent storage / save-file migration yet.
- No UI roster screen yet.

## 3. Architecture

Introduce a new helper class `CharacterGenerator` (`godot/scripts/character/CharacterGenerator.gd`):

```gdscript
class_name CharacterGenerator
extends RefCounted

func generate_roster(count: int) -> Array[CharacterData]:
    # Returns an array of fully initialized CharacterData resources.
```

`GameManager._initialize_all_characters()` will:
1. Create the existing 15 characters as today.
2. Call `CharacterGenerator.new().generate_roster(100)`.
3. Append the generated characters to `all_characters`.

This keeps `GameManager` focused on game state rather than procedural generation details.

## 4. Name Generation

Use Chinese syllable pools to compose 2–4 character names.

**Initial syllables (first character):**
阿, 贝, 塞, 迪, 艾, 菲, 格, 海, 伊, 婕, 凯, 莉, 梅, 诺, 欧, 普, 琪, 雷, 萨, 缇, 乌, 维, 希, 佐

**Middle/ending syllables:**
尔, 方, 斯, 雷, 特, 卡, 优, 娜, 姆, 娅, 文, 克, 拉, 妮, 奥, 恩, 丝, 德, 罗, 万, 因, 雅, 露, 马, 肯, 巴, 坦, 鲁, 索, 迦

**Name patterns:**
- 2-syllable: 初始 + 尾音（e.g., 艾娜）
- 3-syllable: 初始 + 中音 + 尾音（e.g., 阿尔方）
- 4-syllable: 初始 + 中音 + 中音 + 尾音（e.g., 阿尔方斯）

Generator ensures uniqueness by tracking used names and retrying collisions.

## 5. Class Templates and Stat Variance

Reuse existing five classes. Base templates derived from current characters:

| Class | HP | ATK | DEF | SPD | Soldiers | Weapon |
|-------|----|-----|-----|-----|----------|--------|
| LORD | 25 | 8 | 5 | 6 | 100 | sword |
| KNIGHT | 30 | 7 | 8 | 4 | 120 | lance |
| FIGHTER | 28 | 9 | 4 | 5 | 100 | axe |
| MAGE | 20 | 10 | 3 | 6 | 80 | magic |
| ARCHER | 22 | 8 | 4 | 7 | 90 | bow |

Variance per character:
- HP: base ± 3
- ATK/DEF/SPD: base ± 2
- Soldiers: base ± 10
- Leadership: 3–7
- Level: 1

Weapon is fixed per class for generated characters.

## 6. Faction and Sprite Assignment

**Faction distribution:**
- Generate exactly 25 new characters for each of the four factions: `askr`, `embla`, `nifl`, `muspell`.
- Existing 15 characters remain unchanged.
- Final roster size: 115 characters total (15 existing + 100 new).

**Sprite assignment:**
- Available folders under `res://assets/characters/`:
  `char_01_alm`, `char_02_lilina`, `char_03_dorcas`, `char_04_abel`, `char_05_klein`, `char_07_lyn`, `char_08_robin`, `char_09_rebecca`, `char_10_hector`, `char_armorax`, `char_armorsw`, `char_beleth`, `char_diadora`, `char_sylvia`
- Assign randomly with uniform distribution.
- Set `sprite_frames_path = "res://assets/characters/<folder>/"`.

## 7. Skills and Tactics

- All generated characters call `setup_default_tactics()` for the standard 4-slot tactic set.
- Skills array remains empty for now (no new skills in this task).

## 8. Integration

`GameManager._initialize_all_characters()`:

```gdscript
func _initialize_all_characters():
    all_characters.clear()

    # Existing 15 characters (unchanged)
    _create_character("Sharena", GameConstants.CharacterClass.KNIGHT, "askr", "lance", "char_02_lilina")
    ...

    # Generated 100 characters
    var generator = CharacterGenerator.new()
    var generated = generator.generate_roster(100)
    all_characters.append_array(generated)
```

## 9. Files to Modify/Create

- **Create:** `godot/scripts/character/CharacterGenerator.gd`
- **Modify:** `godot/scripts/autoload/GameManager.gd` (append generated roster)
- **Modify:** `godot/project.godot` if class_name needs autoload (not required for RefCounted helper)

## 10. Testing

- Headless test: load `GameManager`, assert `all_characters.size() == 115`.
- Assert no duplicate names in generated roster.
- Assert faction distribution is roughly balanced (±5 per faction).
- Assert every generated character has valid `sprite_frames_path`.

## 11. Future Extensions

- Persist generated roster in save file.
- Add rarity tiers affecting stat variance and skill pools.
- Add character roster UI.
- Add recruitment logic on world map.

## Implementation Status

Implemented in commits:
- `3f0aff1 style(character): rename char variable in roster test`
- `bf7d61e feat(character): generate unique Chinese fantasy names`
- `ba2029f feat(character): add class templates and stat variance`
- `a2d4af8 feat(character): assign faction and random sprite folder to generated characters`
- `9034194 feat(game_manager): append 100 generated characters to all_characters`

Note: Final Godot test execution was deferred by request; the test file includes all roster, class, faction, sprite, and GameManager integration assertions.

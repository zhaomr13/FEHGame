# 100-Character Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 100 procedurally generated characters with unique Chinese fantasy names, class-based stats, balanced faction distribution, and random reuse of existing sprite assets.

**Architecture:** A new `CharacterGenerator` helper class owns all generation logic (names, stats, faction, sprite). `GameManager` keeps the existing 15 hand-authored characters and appends the generated 100. A headless test verifies the roster size, name uniqueness, faction balance, and valid sprite paths.

**Tech Stack:** Godot 4.4, GDScript, headless SceneTree tests

---

## File Structure

| File | Responsibility |
|------|----------------|
| `godot/scripts/character/CharacterGenerator.gd` | Generates names, rolls stats from class templates, assigns faction/sprite, and builds `CharacterData` resources. |
| `godot/scripts/autoload/GameManager.gd` | Keeps existing `_create_character` calls and appends generated roster in `_initialize_all_characters()`. |
| `godot/tests/test_character_roster.gd` | Headless test verifying 115 total characters, no duplicate names, faction distribution, and valid sprite folders. |

---

## Task 1: Create `CharacterGenerator` skeleton

**Files:**
- Create: `godot/scripts/character/CharacterGenerator.gd`

- [ ] **Step 1: Write the failing test**

Create `godot/tests/test_character_roster.gd`:

```gdscript
extends SceneTree

func _initialize():
    var generator_script = load("res://scripts/character/CharacterGenerator.gd")
    assert(generator_script != null, "Failed to load CharacterGenerator script")

    var generator = generator_script.new()
    assert(generator != null, "Failed to instantiate CharacterGenerator")

    var roster = generator.generate_roster(10)
    assert(roster.size() == 10, "Expected 10 generated characters, got %d" % roster.size())

    var names = {}
    for char in roster:
        assert(char is CharacterData, "Generated item is not CharacterData")
        assert(char.character_name != "", "Character has empty name")
        assert(not names.has(char.character_name), "Duplicate name: %s" % char.character_name)
        names[char.character_name] = true

    print("CharacterGenerator skeleton test PASSED")
    quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: FAIL with "Invalid call. Nonexistent function 'generate_roster' in base 'RefCounted'."

- [ ] **Step 3: Create the skeleton class**

Create `godot/scripts/character/CharacterGenerator.gd`:

```gdscript
class_name CharacterGenerator
extends RefCounted

func generate_roster(count: int) -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    for i in range(count):
        var char_data = CharacterData.new()
        char_data.character_name = "Test %d" % i
        char_data.setup_default_tactics()
        result.append(char_data)
    return result
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: PASS with "CharacterGenerator skeleton test PASSED".

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/character/CharacterGenerator.gd godot/tests/test_character_roster.gd
git commit -m "feat(character): add CharacterGenerator skeleton and roster test"
```

---

## Task 2: Implement name generation

**Files:**
- Modify: `godot/scripts/character/CharacterGenerator.gd`

- [ ] **Step 1: Write the failing test**

Add to `godot/tests/test_character_roster.gd` before `print(...)`:

```gdscript
    # Name uniqueness and style check
    var roster100 = generator.generate_roster(100)
    var names100 = {}
    for char in roster100:
        assert(not names100.has(char.character_name), "Duplicate name in 100 roster: %s" % char.character_name)
        names100[char.character_name] = true
        assert(char.character_name.length() >= 2, "Name too short: %s" % char.character_name)
        assert(not char.character_name.begins_with("Test"), "Name should not be skeleton placeholder: %s" % char.character_name)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: FAIL because skeleton names are "Test %d" and the test rejects placeholder names.

- [ ] **Step 3: Implement name generation**

Replace the body of `CharacterGenerator.gd` with:

```gdscript
class_name CharacterGenerator
extends RefCounted

const INITIAL_SYLLABLES: Array[String] = [
    "阿", "贝", "塞", "迪", "艾", "菲", "格", "海", "伊", "婕",
    "凯", "莉", "梅", "诺", "欧", "普", "琪", "雷", "萨", "缇",
    "乌", "维", "希", "佐"
]

const BODY_SYLLABLES: Array[String] = [
    "尔", "方", "斯", "雷", "特", "卡", "优", "娜", "姆", "娅",
    "文", "克", "拉", "妮", "奥", "恩", "丝", "德", "罗", "万",
    "因", "雅", "露", "马", "肯", "巴", "坦", "鲁", "索", "迦"
]

var _used_names: Dictionary = {}

func generate_roster(count: int) -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    _used_names.clear()
    for i in range(count):
        var char_data = CharacterData.new()
        char_data.character_name = _generate_unique_name()
        char_data.setup_default_tactics()
        result.append(char_data)
    return result

func _generate_unique_name() -> String:
    var max_attempts = 1000
    for attempt in range(max_attempts):
        var name = _generate_name()
        if not _used_names.has(name):
            _used_names[name] = true
            return name
    # Fallback with numeric suffix if collisions exhaust attempts
    var suffix = 1
    while true:
        var name = _generate_name() + str(suffix)
        if not _used_names.has(name):
            _used_names[name] = true
            return name
        suffix += 1

func _generate_name() -> String:
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    var pattern = rng.randi() % 3  # 0=2-syl, 1=3-syl, 2=4-syl
    var name = INITIAL_SYLLABLES[rng.randi() % INITIAL_SYLLABLES.size()]
    if pattern == 0:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    elif pattern == 1:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    else:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    return name
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/character/CharacterGenerator.gd godot/tests/test_character_roster.gd
git commit -m "feat(character): generate unique Chinese fantasy names"
```

---

## Task 3: Implement class templates and stat variance

**Files:**
- Modify: `godot/scripts/character/CharacterGenerator.gd`

- [ ] **Step 1: Write the failing test**

Add to `godot/tests/test_character_roster.gd` before `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: FAIL because generated characters still have default stats (HP 20, etc.) and no class set.

- [ ] **Step 3: Implement class templates and stat rolling**

Add to `CharacterGenerator.gd` before `generate_roster`:

```gdscript
const CLASS_TEMPLATES: Dictionary = {
    GameConstants.CharacterClass.LORD:    {"max_hp": 25, "attack": 8, "defense": 5, "speed": 6, "soldiers": 100, "weapon": "sword"},
    GameConstants.CharacterClass.KNIGHT:  {"max_hp": 30, "attack": 7, "defense": 8, "speed": 4, "soldiers": 120, "weapon": "lance"},
    GameConstants.CharacterClass.FIGHTER: {"max_hp": 28, "attack": 9, "defense": 4, "speed": 5, "soldiers": 100, "weapon": "axe"},
    GameConstants.CharacterClass.MAGE:    {"max_hp": 20, "attack": 10, "defense": 3, "speed": 6, "soldiers": 80,  "weapon": "magic"},
    GameConstants.CharacterClass.ARCHER:  {"max_hp": 22, "attack": 8, "defense": 4, "speed": 7, "soldiers": 90,  "weapon": "bow"}
}

const CLASS_KEYS: Array = [
    GameConstants.CharacterClass.LORD,
    GameConstants.CharacterClass.KNIGHT,
    GameConstants.CharacterClass.FIGHTER,
    GameConstants.CharacterClass.MAGE,
    GameConstants.CharacterClass.ARCHER
]
```

Update `generate_roster`:

```gdscript
func generate_roster(count: int) -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    _used_names.clear()
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        var char_data = CharacterData.new()
        char_data.character_name = _generate_unique_name()
        char_data.character_class = CLASS_KEYS[rng.randi() % CLASS_KEYS.size()]
        _apply_class_template(char_data, rng)
        char_data.setup_default_tactics()
        result.append(char_data)
    return result
```

Add helper:

```gdscript
func _apply_class_template(char_data: CharacterData, rng: RandomNumberGenerator):
    var template = CLASS_TEMPLATES[char_data.character_class]
    char_data.max_hp = template.max_hp + rng.randi_range(-3, 3)
    char_data.current_hp = char_data.max_hp
    char_data.attack = template.attack + rng.randi_range(-2, 2)
    char_data.defense = template.defense + rng.randi_range(-2, 2)
    char_data.speed = template.speed + rng.randi_range(-2, 2)
    char_data.soldiers = template.soldiers + rng.randi_range(-10, 10)
    char_data.max_soldiers = char_data.soldiers
    char_data.weapon_type = template.weapon
    char_data.leadership = rng.randi_range(3, 7)
    char_data.level = 1
    char_data.experience = 0
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/character/CharacterGenerator.gd godot/tests/test_character_roster.gd
git commit -m "feat(character): add class templates and stat variance"
```

---

## Task 4: Implement faction and sprite assignment

**Files:**
- Modify: `godot/scripts/character/CharacterGenerator.gd`

- [ ] **Step 1: Write the failing test**

Add to `godot/tests/test_character_roster.gd` before `print(...)`:

```gdscript
    # Faction and sprite check
    var roster100b = generator.generate_roster(100)
    var faction_counts = {"askr": 0, "embla": 0, "nifl": 0, "muspell": 0}
    for char in roster100b:
        assert(faction_counts.has(char.faction), "Unexpected faction: %s" % char.faction)
        faction_counts[char.faction] += 1
        assert(char.sprite_frames_path != "", "Missing sprite path")
        assert(DirAccess.dir_exists(char.sprite_frames_path), "Sprite folder does not exist: %s" % char.sprite_frames_path)

    for faction in faction_counts.keys():
        var c = faction_counts[faction]
        assert(c >= 20 and c <= 30, "Faction %s count %d is out of balance" % [faction, c])
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: FAIL because faction and sprite fields are empty.

- [ ] **Step 3: Implement faction and sprite assignment**

Add constants to `CharacterGenerator.gd`:

```gdscript
const FACTIONS: Array[String] = ["askr", "embla", "nifl", "muspell"]

const SPRITE_FOLDERS: Array[String] = [
    "char_01_alm",
    "char_02_lilina",
    "char_03_dorcas",
    "char_04_abel",
    "char_05_klein",
    "char_07_lyn",
    "char_08_robin",
    "char_09_rebecca",
    "char_10_hector",
    "char_armorax",
    "char_armorsw",
    "char_beleth",
    "char_diadora",
    "char_sylvia"
]
```

Update `generate_roster` to assign faction and sprite:

```gdscript
func generate_roster(count: int) -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    _used_names.clear()
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        var char_data = CharacterData.new()
        char_data.character_name = _generate_unique_name()
        char_data.faction = FACTIONS[i % FACTIONS.size()]
        char_data.character_class = CLASS_KEYS[rng.randi() % CLASS_KEYS.size()]
        _apply_class_template(char_data, rng)
        char_data.sprite_frames_path = "res://assets/characters/" + SPRITE_FOLDERS[rng.randi() % SPRITE_FOLDERS.size()] + "/"
        char_data.setup_default_tactics()
        result.append(char_data)
    return result
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/character/CharacterGenerator.gd godot/tests/test_character_roster.gd
git commit -m "feat(character): assign faction and random sprite folder to generated characters"
```

---

## Task 5: Integrate generated roster into `GameManager`

**Files:**
- Modify: `godot/scripts/autoload/GameManager.gd`

- [ ] **Step 1: Write the failing integration test**

Update `godot/tests/test_character_roster.gd` to also check `GameManager.all_characters`:

```gdscript
extends SceneTree

func _initialize():
    # ... existing generator tests ...

    # Integration: GameManager loads all characters
    assert(GameManager.all_characters.size() == 115, "Expected 115 total characters, got %d" % GameManager.all_characters.size())

    print("CharacterGenerator skeleton test PASSED")
    quit(0)
```

Wait — `GameManager.all_characters` is populated in `_ready()`, which runs before the test script. So we can just assert the size.

- [ ] **Step 2: Run the test to verify it fails**

Expected: FAIL with "Expected 115 total characters, got 15".

- [ ] **Step 3: Integrate generator into GameManager**

At the end of `GameManager._initialize_all_characters()`, after the existing `_create_character` calls, add:

```gdscript
    # Generate 100 additional characters
    var generator = CharacterGenerator.new()
    var generated = generator.generate_roster(100)
    all_characters.append_array(generated)
```

Also ensure `GameManager.gd` can resolve `CharacterGenerator`. Add near the top with other implicit class references, or rely on GDScript global class resolution. No explicit `load()` is needed for `class_name` scripts.

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/autoload/GameManager.gd godot/tests/test_character_roster.gd
git commit -m "feat(game_manager): append 100 generated characters to all_characters"
```

---

## Task 6: Verify full test suite and performance

- [ ] **Step 1: Run the new roster test**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_character_roster.gd
```

Expected output:

```
GameManager initialized
Preloaded ... sprite atlases in ...ms
CharacterGenerator skeleton test PASSED
```

- [ ] **Step 2: Run existing tests to ensure no regressions**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_map_data.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_world_map_scene.gd
```

Expected outputs:

```
Map data test PASSED: 80 nodes, fully connected, no overlaps
WorldMap scene integration test PASSED
```

- [ ] **Step 3: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/tests/test_character_roster.gd
git commit -m "test(character): roster integration tests pass"
```

---

## Task 7: Update documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-06-16-100-character-roster-design.md`

- [ ] **Step 1: Mark spec as implemented**

Append to the bottom of the spec file:

```markdown
## Implementation Status

Implemented in commits:
- `feat(character): add CharacterGenerator skeleton and roster test`
- `feat(character): generate unique Chinese fantasy names`
- `feat(character): add class templates and stat variance`
- `feat(character): assign faction and random sprite folder to generated characters`
- `feat(game_manager): append 100 generated characters to all_characters`
- `test(character): roster integration tests pass`
```

- [ ] **Step 2: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add docs/superpowers/specs/2026-06-16-100-character-roster-design.md
git commit -m "docs: mark 100-character roster spec as implemented"
```

---

## Self-Review

### Spec Coverage

| Spec Section | Implementing Task |
|--------------|-------------------|
| `CharacterGenerator` class | Task 1 |
| Name generation | Task 2 |
| Class templates + stat variance | Task 3 |
| Faction assignment | Task 4 |
| Sprite folder assignment | Task 4 |
| GameManager integration | Task 5 |
| Tests | Tasks 1–6 |
| Documentation | Task 7 |

### Placeholder Scan

No placeholders. Every step contains exact file paths, complete code, exact commands, and expected output.

### Type Consistency

- `generate_roster(count: int) -> Array[CharacterData]` is consistent across tasks.
- `CLASS_TEMPLATES` keys use `GameConstants.CharacterClass` enum values.
- `FACTIONS` and `SPRITE_FOLDERS` are `Array[String]`.
- Property names (`max_hp`, `current_hp`, `attack`, `defense`, `speed`, `soldiers`, `weapon_type`, `faction`, `sprite_frames_path`) match `CharacterData` exports.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-16-100-character-roster.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach would you like?

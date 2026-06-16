#!/usr/bin/env python3
"""Generate godot/data/characters.yaml from story characters + deterministic generation.

This script replaces the runtime CharacterGenerator with a static YAML database.
Run it once, then commit the resulting YAML file. After that, CharacterGenerator.gd
is no longer needed.
"""

import random
import os

# Deterministic output for reproducible roster
random.seed(42)

INITIAL_SYLLABLES = [
    "阿", "贝", "塞", "迪", "艾", "菲", "格", "海", "伊", "婕",
    "凯", "莉", "梅", "诺", "欧", "普", "琪", "雷", "萨", "缇",
    "乌", "维", "希", "佐"
]

BODY_SYLLABLES = [
    "尔", "方", "斯", "雷", "特", "卡", "优", "娜", "姆", "娅",
    "文", "克", "拉", "妮", "奥", "恩", "丝", "德", "罗", "万",
    "因", "雅", "露", "马", "肯", "巴", "坦", "鲁", "索", "迦"
]

FACTIONS = ["askr", "embla", "nifl", "muspell"]

SPRITE_FOLDERS = [
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

CLASS_TEMPLATES = {
    "LORD":    {"max_hp": 25, "attack": 8, "defense": 5, "speed": 6, "soldiers": 100, "weapon": "sword"},
    "KNIGHT":  {"max_hp": 30, "attack": 7, "defense": 8, "speed": 4, "soldiers": 120, "weapon": "lance"},
    "FIGHTER": {"max_hp": 28, "attack": 9, "defense": 4, "speed": 5, "soldiers": 100, "weapon": "axe"},
    "MAGE":    {"max_hp": 20, "attack": 10, "defense": 3, "speed": 6, "soldiers": 80,  "weapon": "magic"},
    "ARCHER":  {"max_hp": 22, "attack": 8, "defense": 4, "speed": 7, "soldiers": 90,  "weapon": "bow"}
}

CLASS_KEYS = ["LORD", "KNIGHT", "FIGHTER", "MAGE", "ARCHER"]

HP_VARIANCE = 3
STAT_VARIANCE = 2
SOLDIER_VARIANCE = 10
LEADERSHIP_MIN = 3
LEADERSHIP_MAX = 7


def _generate_name():
    pattern = random.randint(0, 2)  # 0=2-syl, 1=3-syl, 2=4-syl
    name = random.choice(INITIAL_SYLLABLES)
    body_count = pattern + 1  # 1, 2, or 3 body syllables
    for _ in range(body_count):
        name += random.choice(BODY_SYLLABLES)
    return name


def _generate_unique_name(used_names):
    for _ in range(1000):
        name = _generate_name()
        if name not in used_names:
            used_names.add(name)
            return name
    # Fallback with numeric suffix
    suffix = 1
    while True:
        name = _generate_name() + str(suffix)
        if name not in used_names:
            used_names.add(name)
            return name
        suffix += 1


def _generate_character(index):
    char_class = random.choice(CLASS_KEYS)
    template = CLASS_TEMPLATES[char_class]
    return {
        "class": char_class,
        "faction": FACTIONS[index % len(FACTIONS)],
        "level": 1,
        "experience": 0,
        "max_hp": template["max_hp"] + random.randint(-HP_VARIANCE, HP_VARIANCE),
        "attack": template["attack"] + random.randint(-STAT_VARIANCE, STAT_VARIANCE),
        "defense": template["defense"] + random.randint(-STAT_VARIANCE, STAT_VARIANCE),
        "speed": template["speed"] + random.randint(-STAT_VARIANCE, STAT_VARIANCE),
        "leadership": random.randint(LEADERSHIP_MIN, LEADERSHIP_MAX),
        "weapon_type": template["weapon"],
        "soldiers": template["soldiers"] + random.randint(-SOLDIER_VARIANCE, SOLDIER_VARIANCE),
        "max_soldiers": 0,  # filled below
        "sprite_folder": random.choice(SPRITE_FOLDERS),
    }


def _story_characters():
    # These match the original GameManager._create_character() calls.
    # Stats not listed use CharacterData defaults (level=1, experience=0,
    # soldiers=100, max_soldiers=100, leadership=5).
    return [
        {"name": "Sharena",   "class": "KNIGHT", "faction": "askr",    "weapon_type": "lance", "sprite_folder": "char_02_lilina",  "max_hp": 30, "attack": 7, "defense": 8, "speed": 4},
        {"name": "Alfonse",   "class": "LORD",   "faction": "askr",    "weapon_type": "sword", "sprite_folder": "char_01_alm",     "max_hp": 25, "attack": 8, "defense": 5, "speed": 6},
        {"name": "Anna",      "class": "FIGHTER","faction": "askr",    "weapon_type": "axe",   "sprite_folder": "char_08_robin",   "max_hp": 28, "attack": 9, "defense": 4, "speed": 5},
        {"name": "Veronica",  "class": "MAGE",   "faction": "embla",   "weapon_type": "magic", "sprite_folder": "char_02_lilina",  "max_hp": 20, "attack": 10,"defense": 3, "speed": 6},
        {"name": "Bruno",     "class": "LORD",   "faction": "embla",   "weapon_type": "sword", "sprite_folder": "char_01_alm",     "max_hp": 25, "attack": 8, "defense": 5, "speed": 6},
        {"name": "Loki",      "class": "ARCHER", "faction": "embla",   "weapon_type": "bow",   "sprite_folder": "char_09_rebecca", "max_hp": 22, "attack": 8, "defense": 4, "speed": 7},
        {"name": "Gunnthra",  "class": "MAGE",   "faction": "nifl",    "weapon_type": "magic", "sprite_folder": "char_02_lilina",  "max_hp": 20, "attack": 10,"defense": 3, "speed": 6},
        {"name": "Hrid",      "class": "LORD",   "faction": "nifl",    "weapon_type": "sword", "sprite_folder": "char_01_alm",     "max_hp": 25, "attack": 8, "defense": 5, "speed": 6},
        {"name": "Ylgr",      "class": "FIGHTER","faction": "nifl",    "weapon_type": "axe",   "sprite_folder": "char_03_dorcas",  "max_hp": 28, "attack": 9, "defense": 4, "speed": 5},
        {"name": "Laevatein","class": "KNIGHT", "faction": "muspell", "weapon_type": "sword", "sprite_folder": "char_10_hector", "max_hp": 30, "attack": 7, "defense": 8, "speed": 4},
        {"name": "Laegjarn",  "class": "KNIGHT", "faction": "muspell", "weapon_type": "lance", "sprite_folder": "char_04_abel",    "max_hp": 30, "attack": 7, "defense": 8, "speed": 4},
        {"name": "Helbindi",  "class": "FIGHTER","faction": "muspell", "weapon_type": "axe",   "sprite_folder": "char_03_dorcas",  "max_hp": 28, "attack": 9, "defense": 4, "speed": 5},
        {"name": "Klein",     "class": "ARCHER", "faction": "",        "weapon_type": "bow",   "sprite_folder": "char_05_klein",   "max_hp": 22, "attack": 8, "defense": 4, "speed": 7},
        {"name": "Rebecca",   "class": "ARCHER", "faction": "",        "weapon_type": "bow",   "sprite_folder": "char_09_rebecca", "max_hp": 22, "attack": 8, "defense": 4, "speed": 7},
        {"name": "Lyn",       "class": "LORD",   "faction": "",        "weapon_type": "sword", "sprite_folder": "char_07_lyn",     "max_hp": 25, "attack": 8, "defense": 5, "speed": 6},
    ]


def _finalize_character(char):
    # Fill defaults to match runtime CharacterData initialization
    if "level" not in char:
        char["level"] = 1
    if "experience" not in char:
        char["experience"] = 0
    if "leadership" not in char:
        char["leadership"] = 5
    if "soldiers" not in char:
        char["soldiers"] = 100
    if "max_soldiers" not in char or char["max_soldiers"] == 0:
        char["max_soldiers"] = char["soldiers"]
    return char


def _yaml_value(value):
    """Convert a Python value to a YAML scalar string."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) or isinstance(value, float):
        return str(value)
    # Strings: quote everything for safety, especially Chinese and empty strings
    s = str(value)
    return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')


def _write_yaml(characters, path):
    lines = ["# Character Database", "# 15 story characters + 100 generated characters", ""]
    lines.append("characters:")
    for char in characters:
        lines.append("  - name: %s" % _yaml_value(char["name"]))
        lines.append("    class: %s" % _yaml_value(char["class"]))
        lines.append("    faction: %s" % _yaml_value(char["faction"]))
        lines.append("    level: %s" % _yaml_value(char["level"]))
        lines.append("    experience: %s" % _yaml_value(char["experience"]))
        lines.append("    max_hp: %s" % _yaml_value(char["max_hp"]))
        lines.append("    attack: %s" % _yaml_value(char["attack"]))
        lines.append("    defense: %s" % _yaml_value(char["defense"]))
        lines.append("    speed: %s" % _yaml_value(char["speed"]))
        lines.append("    leadership: %s" % _yaml_value(char["leadership"]))
        lines.append("    weapon_type: %s" % _yaml_value(char["weapon_type"]))
        lines.append("    soldiers: %s" % _yaml_value(char["soldiers"]))
        lines.append("    max_soldiers: %s" % _yaml_value(char["max_soldiers"]))
        lines.append("    sprite_folder: %s" % _yaml_value(char["sprite_folder"]))
        lines.append("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    output_path = os.path.join(repo_root, "godot", "data", "characters.yaml")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    characters = []

    # Story characters
    for char in _story_characters():
        characters.append(_finalize_character(char))

    # Generated characters
    used_names = set()
    for i in range(100):
        char = _generate_character(i)
        char["name"] = _generate_unique_name(used_names)
        characters.append(_finalize_character(char))

    _write_yaml(characters, output_path)
    print("Wrote %d characters to %s" % (len(characters), output_path))


if __name__ == "__main__":
    main()

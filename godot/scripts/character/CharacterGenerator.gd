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
    return ""  # Unreachable, but satisfies GDScript static analyzer

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

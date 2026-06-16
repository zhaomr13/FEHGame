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

extends Control

signal faction_selected(faction: String)

const FACTIONS = {
    "askr": {
        "name": "Askr Kingdom",
        "description": "Balanced faction with strong recruitment",
        "bonus": "+20% recruit success",
        "color": Color(0.2, 0.6, 1.0)
    },
    "embla": {
        "name": "Embla Empire",
        "description": "Military-focused with siege advantages",
        "bonus": "-20% siege cost",
        "color": Color(0.8, 0.2, 0.2)
    },
    "nifl": {
        "name": "Nifl Kingdom",
        "description": "Fast and agile with speed bonuses",
        "bonus": "+10% battle speed",
        "color": Color(0.2, 0.8, 0.8)
    }
}

@onready var faction_list = $VBoxContainer/FactionList

func _ready():
    create_faction_buttons()

func create_faction_buttons():
    for faction_id in FACTIONS.keys():
        var faction = FACTIONS[faction_id]

        var button = Button.new()
        button.text = faction.name
        button.custom_minimum_size = Vector2(300, 80)
        button.pressed.connect(_on_faction_button_pressed.bind(faction_id))

        # Style the button
        var style = StyleBoxFlat.new()
        style.bg_color = faction.color
        style.corner_radius_top_left = 10
        style.corner_radius_top_right = 10
        style.corner_radius_bottom_left = 10
        style.corner_radius_bottom_right = 10
        button.add_theme_stylebox_override("normal", style)

        # Add description label
        var vbox = VBoxContainer.new()
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER

        var name_label = Label.new()
        name_label.text = faction.name
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 20)

        var desc_label = Label.new()
        desc_label.text = faction.description + "\n" + faction.bonus
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_label.add_theme_font_size_override("font_size", 14)

        vbox.add_child(name_label)
        vbox.add_child(desc_label)

        button.add_child(vbox)
        faction_list.add_child(button)

func _on_faction_button_pressed(faction_id: String):
    faction_selected.emit(faction_id)
    visible = false

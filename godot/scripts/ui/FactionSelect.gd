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
	# Clear existing children
	for child in faction_list.get_children():
		child.queue_free()

	for faction_id in FACTIONS.keys():
		var faction = FACTIONS[faction_id]

		# Create a container for each faction button
		var container = PanelContainer.new()
		container.custom_minimum_size = Vector2(500, 100)

		# Style the container
		var style = StyleBoxFlat.new()
		style.bg_color = faction.color.darkened(0.3)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = faction.color
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		container.add_theme_stylebox_override("panel", style)

		# Inner layout
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_child(vbox)

		# Name label
		var name_label = Label.new()
		name_label.text = faction.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(name_label)

		# Description
		var desc_label = Label.new()
		desc_label.text = faction.description
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(desc_label)

		# Bonus
		var bonus_label = Label.new()
		bonus_label.text = "Bonus: " + faction.bonus
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.add_theme_font_size_override("font_size", 12)
		bonus_label.add_theme_color_override("font_color", faction.color.lightened(0.3))
		vbox.add_child(bonus_label)

		# Make the container clickable
		var button = Button.new()
		button.text = "Select"
		button.custom_minimum_size = Vector2(100, 30)
		button.pressed.connect(_on_faction_button_pressed.bind(faction_id))
		vbox.add_child(button)

		faction_list.add_child(container)

func _on_faction_button_pressed(faction_id: String):
	faction_selected.emit(faction_id)
	visible = false

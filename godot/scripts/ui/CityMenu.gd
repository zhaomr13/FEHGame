extends Control

signal city_closed
signal heal_army
signal recruit_troops
signal open_formation
signal deploy_army
signal army_selected(army: Army)

var current_city_name: String = ""
var gold_reward: int = 100
var is_current_city: bool = false
var _garrisoned_armies: Array[Army] = []

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var info_label = $Panel/VBoxContainer/InfoLabel
@onready var garrison_label = $Panel/VBoxContainer/GarrisonLabel
@onready var garrison_list = $Panel/VBoxContainer/GarrisonScroll/GarrisonList
@onready var deploy_button = $Panel/VBoxContainer/DeployButton

func _ready():
	visible = false

	$Panel/VBoxContainer/ButtonContainer/HealButton.pressed.connect(_on_heal)
	$Panel/VBoxContainer/ButtonContainer/RecruitButton.pressed.connect(_on_recruit)
	$Panel/VBoxContainer/ButtonContainer/FormationButton.pressed.connect(_on_formation)
	$Panel/VBoxContainer/CloseButton.pressed.connect(_on_close)

	if deploy_button:
		deploy_button.pressed.connect(_on_deploy)

func show_city(city_name: String, city_type: int, is_current: bool = false, garrisoned_armies: Array[Army] = []):
	current_city_name = city_name
	is_current_city = is_current
	_garrisoned_armies = garrisoned_armies
	visible = true

	title_label.text = city_name

	var city_type_name = ""
	match city_type:
		GameConstants.NodeType.CITY:
			city_type_name = "Major City"
			gold_reward = 200
		GameConstants.NodeType.FORT:
			city_type_name = "Fortress"
			gold_reward = 150
		GameConstants.NodeType.VILLAGE:
			city_type_name = "Village"
			gold_reward = 100

	if is_current:
		info_label.text = "Type: %s\nGold Income: %d\n\nYou are here. Manage your army or deploy to attack." % [city_type_name, gold_reward]
		if deploy_button:
			deploy_button.visible = true
			deploy_button.text = "Deploy Army"
	else:
		info_label.text = "Type: %s\nGold Income: %d\n\nThis city is under your control." % [city_type_name, gold_reward]
		if deploy_button:
			deploy_button.visible = false

	_rebuild_garrison_list()

	if is_current:
		GameManager.player_gold += gold_reward

func _rebuild_garrison_list():
	if not garrison_list:
		return

	for child in garrison_list.get_children():
		child.queue_free()

	if garrison_label:
		garrison_label.visible = true

	if _garrisoned_armies.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No armies stationed here."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.8, 0.8, 0.8)
		garrison_list.add_child(empty_label)
		return

	for army in _garrisoned_armies:
		if not is_instance_valid(army):
			continue
		var button = Button.new()
		button.text = "%s (%s)" % [army.army_name, army.get_leader_name()]
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_garrison_army_pressed.bind(army))
		garrison_list.add_child(button)

func _on_garrison_army_pressed(army: Army):
	army_selected.emit(army)
	visible = false

func _on_heal():
	heal_army.emit()
	for character in GameManager.player_army:
		character.current_hp = character.max_hp
		character.soldiers = character.max_soldiers
	info_label.text = "Army fully healed!"

func _on_recruit():
	recruit_troops.emit()
	for character in GameManager.player_army:
		character.soldiers = min(character.soldiers + 50, character.max_soldiers)
	GameManager.player_gold -= 50
	info_label.text = "Recruited 50 soldiers per unit! (-50 gold)"

func _on_formation():
	open_formation.emit()
	visible = false

func _on_deploy():
	deploy_army.emit()

func _on_close():
	visible = false
	city_closed.emit()

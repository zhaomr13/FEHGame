extends Control

signal city_closed
signal heal_army
signal recruit_troops
signal open_formation
signal deploy_army

var current_city_name: String = ""
var gold_reward: int = 100
var is_current_city: bool = false

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var info_label = $Panel/VBoxContainer/InfoLabel
@onready var deploy_button = $Panel/VBoxContainer/DeployButton

func _ready():
	visible = false

	# Connect buttons
	$Panel/VBoxContainer/ButtonContainer/HealButton.pressed.connect(_on_heal)
	$Panel/VBoxContainer/ButtonContainer/RecruitButton.pressed.connect(_on_recruit)
	$Panel/VBoxContainer/ButtonContainer/FormationButton.pressed.connect(_on_formation)
	$Panel/VBoxContainer/CloseButton.pressed.connect(_on_close)

	if deploy_button:
		deploy_button.pressed.connect(_on_deploy)

func show_city(city_name: String, city_type: int, is_current: bool = false):
	current_city_name = city_name
	is_current_city = is_current
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

	# Add gold to player (only once per visit)
	if is_current:
		GameManager.player_gold += gold_reward

func _on_heal():
	heal_army.emit()
	# Heal all characters
	for character in GameManager.player_army:
		character.current_hp = character.max_hp
		character.soldiers = character.max_soldiers
	info_label.text = "Army fully healed!"

func _on_recruit():
	recruit_troops.emit()
	# Add soldiers to all characters
	for character in GameManager.player_army:
		character.soldiers = min(character.soldiers + 50, character.max_soldiers)
	GameManager.player_gold -= 50
	info_label.text = "Recruited 50 soldiers per unit! (-50 gold)"

func _on_formation():
	open_formation.emit()
	info_label.text = "Formation editor would open here..."

func _on_deploy():
	deploy_army.emit()

func _on_close():
	visible = false
	city_closed.emit()

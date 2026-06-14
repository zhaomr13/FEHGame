class_name BattleUnit
extends Node2D

var character_data: CharacterData
var battle_position: int = 0  # 0-2: Front line, 3-5: Back line
var is_player_unit: bool = true
var current_target: BattleUnit = null

# Time bar for active time battle
var time_bar: float = 0.0
var max_time_bar: float = 100.0
var is_ready: bool = false

var character: Character = null

@onready var tactics: BattleUnitTactics = $BattleUnitTactics
@onready var combat: BattleUnitCombat = $BattleUnitCombat

func _ready():
	max_time_bar = 100.0
	character = $Character

func setup(data: CharacterData, position: int, is_player: bool):
	# Ensure character node is ready
	if character == null:
		character = $Character

	character_data = data
	battle_position = position
	is_player_unit = is_player

	if character:
		character.character_data = data
		character.setup_sprite()
		character.set_state(Character.State.IDLE)

func update_time_bar(delta: float):
	"""Called every frame to fill time bar based on speed"""
	if is_ready or character_data.is_defeated():
		return

	# Speed determines fill rate (increased for faster battles)
	var fill_rate = character_data.speed * 50.0  # 5x faster
	time_bar += fill_rate * delta

	if time_bar >= max_time_bar:
		time_bar = max_time_bar
		is_ready = true
		enter_ready_state()

func enter_ready_state():
	"""Character is ready to act - evaluate tactics"""
	if character:
		character.set_state(Character.State.SELECTED)

func process_turn(all_enemy_units: Array, all_ally_units: Array):
	"""Process a full turn for this unit"""
	if character_data.is_defeated():
		return

	# Fill time bar until ready (slower for better visibility)
	var wait_time = 0.0
	var max_wait = 2.0
	while not is_ready and wait_time < max_wait:
		update_time_bar(0.016)  # ~60fps delta
		wait_time += 0.05
		await get_tree().create_timer(0.02).timeout

	if character_data.is_defeated():
		return

	# Force ready if timeout
	is_ready = true

	# Execute tactics (delegates to BattleUnitTactics child)
	await tactics.execute_tactics(all_enemy_units, all_ally_units)

# API wrappers - preserved so external callers don't break
func perform_attack(target: BattleUnit, use_skill: bool):
	await combat.perform_attack(target, use_skill)

func take_damage(amount: int):
	await combat.take_damage(amount)

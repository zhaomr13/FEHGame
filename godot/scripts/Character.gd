extends CharacterBody2D

@export var character_name: String = "Diadora"  # "Diadora" or "ArmorAX"
@export var is_player: bool = true
@export var move_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State { IDLE, WALK, ATTACK }
var current_state: State = State.IDLE
var facing_right: bool = true

func _ready():
	# Load atlas at runtime
	var json_path = "res://assets/" + character_name + ".json"
	var png_path = "res://assets/" + character_name + ".png"

	var atlas_loader = preload("res://scripts/AtlasLoader.gd")
	animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)

	animated_sprite.play("Idle")

	# Flip if not player (face left)
	if not is_player:
		facing_right = false
		animated_sprite.flip_h = true

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle(delta)
		State.WALK:
			handle_walk(delta)
		State.ATTACK:
			handle_attack(delta)

func handle_idle(delta):
	var input_dir = get_input_direction()

	if Input.is_action_just_pressed("attack") and is_player:
		change_state(State.ATTACK)
	elif input_dir != 0:
		change_state(State.WALK)

func handle_walk(delta):
	var input_dir = get_input_direction()

	if Input.is_action_just_pressed("attack") and is_player:
		change_state(State.ATTACK)
		return

	if input_dir == 0:
		change_state(State.IDLE)
	else:
		velocity.x = input_dir * move_speed
		# Flip sprite based on direction
		if input_dir > 0 and not facing_right:
			facing_right = true
			animated_sprite.flip_h = false
		elif input_dir < 0 and facing_right:
			facing_right = false
			animated_sprite.flip_h = true

		move_and_slide()

func handle_attack(delta):
	# Wait for animation to finish
	pass

func change_state(new_state: State):
	current_state = new_state

	match new_state:
		State.IDLE:
			animated_sprite.play("Idle")
			velocity = Vector2.ZERO
		State.WALK:
			animated_sprite.play("Idle")  # Use Idle for walk (no walk anim)
		State.ATTACK:
			animated_sprite.play("Attack1")
			animated_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

func _on_attack_finished():
	change_state(State.IDLE)

func get_input_direction() -> int:
	if not is_player:
		return 0

	var dir = 0
	if Input.is_action_pressed("ui_left"):
		dir -= 1
	if Input.is_action_pressed("ui_right"):
		dir += 1
	return dir

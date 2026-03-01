class_name Character
extends Node2D

@export var character_data: CharacterData

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

enum State { IDLE, SELECTED, MOVING, ATTACKING, DAMAGED, DEFEATED }
var current_state: State = State.IDLE
var grid_position: Vector2i

func _ready():
	if character_data:
		setup_sprite()
		set_state(State.IDLE)

func setup_sprite():
	# Load atlas using AtlasLoader
	if character_data.sprite_frames_path.is_empty():
		push_error("No sprite_frames_path set for character: " + character_data.character_name)
		return

	var atlas_loader = preload("res://scripts/AtlasLoader.gd")
	var json_path = character_data.sprite_frames_path.replace(".png", ".json")
	var png_path = character_data.sprite_frames_path

	animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)
	if animated_sprite.sprite_frames:
		# Play first available animation if Idle doesn't exist
		if animated_sprite.sprite_frames.has_animation("Idle"):
			animated_sprite.play("Idle")
		else:
			var anims = animated_sprite.sprite_frames.get_animation_names()
			if anims.size() > 0:
				animated_sprite.play(anims[0])

func set_state(new_state: State):
	current_state = new_state
	if not animated_sprite.sprite_frames:
		return

	match new_state:
		State.IDLE:
			if animated_sprite.sprite_frames.has_animation("Idle"):
				animated_sprite.play("Idle")
			selection_indicator.visible = false
		State.SELECTED:
			if animated_sprite.sprite_frames.has_animation("Ready"):
				animated_sprite.play("Ready")
			selection_indicator.visible = true
		State.MOVING:
			if animated_sprite.sprite_frames.has_animation("Ready"):
				animated_sprite.play("Ready")
		State.ATTACKING:
			if animated_sprite.sprite_frames.has_animation("Attack1"):
				animated_sprite.play("Attack1")
		State.DAMAGED:
			if animated_sprite.sprite_frames.has_animation("Damage"):
				animated_sprite.play("Damage")
		State.DEFEATED:
			if animated_sprite.sprite_frames.has_animation("Damage"):
				animated_sprite.play("Damage")
				animated_sprite.pause()
			modulate = Color(0.5, 0.5, 0.5, 1.0)

func play_attack_animation() -> String:
	var attack_type = "Attack1"
	if randf() > 0.5 and animated_sprite.sprite_frames.has_animation("Attack2"):
		attack_type = "Attack2"
	animated_sprite.play(attack_type)
	return attack_type

func take_damage(amount: int):
	character_data.take_damage(amount)
	set_state(State.DAMAGED)
	await animated_sprite.animation_finished
	if character_data.is_defeated():
		set_state(State.DEFEATED)
	else:
		set_state(State.IDLE)

func setup_from_atlas(json_path: String, png_path: String):
	var atlas_loader = preload("res://scripts/AtlasLoader.gd")
	animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)
	animated_sprite.play("Idle")

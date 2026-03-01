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
    var atlas_loader = preload("res://scripts/AtlasLoader.gd")
    var json_path = character_data.sprite_frames_path.replace(".png", ".json")
    var png_path = character_data.sprite_frames_path

    animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)
    if animated_sprite.sprite_frames:
        animated_sprite.play("Idle")

func set_state(new_state: State):
    current_state = new_state
    match new_state:
        State.IDLE:
            animated_sprite.play("Idle")
            selection_indicator.visible = false
        State.SELECTED:
            animated_sprite.play("Ready")
            selection_indicator.visible = true
        State.MOVING:
            animated_sprite.play("Ready")
        State.ATTACKING:
            animated_sprite.play("Attack1")
        State.DAMAGED:
            animated_sprite.play("Damage")
        State.DEFEATED:
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

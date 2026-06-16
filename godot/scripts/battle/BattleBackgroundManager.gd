class_name BattleBackgroundManager
extends Node2D

const BATTLE_BACKGROUNDS = {
	"plain": "res://assets/battle/backgrounds/plain_bg.png",
	"plain_fg": "res://assets/battle/backgrounds/plain_fg.png",
	"forest": "res://assets/battle/backgrounds/forest_bg.png",
	"forest_fg": "res://assets/battle/backgrounds/forest_fg.png",
	"inside": "res://assets/battle/backgrounds/inside_bg.png",
	"inside_fg": "res://assets/battle/backgrounds/inside_fg.png",
	"brave_attack": "res://assets/battle/backgrounds/brave_attack_bg.png",
	"brave_attack_fg": "res://assets/battle/backgrounds/brave_attack_fg.png",
	"river": "res://assets/battle/backgrounds/river_bg.png",
	"river_fg": "res://assets/battle/backgrounds/river_fg.png",
	"plain_forest": "res://assets/battle/backgrounds/plain_forest_bg.png",
	"plain_forest_fg": "res://assets/battle/backgrounds/plain_forest_fg.png"
}

@onready var background_sprite: Sprite2D = $"../Background"
@onready var foreground_sprite: Sprite2D = $"../Foreground"

func set_background(bg_type: String):
	# Use solid black for battle background; ignore bg_type for now
	var black_image = Image.create(1, 1, false, Image.FORMAT_RGB8)
	black_image.fill(Color.BLACK)
	var black_texture = ImageTexture.create_from_image(black_image)

	if background_sprite:
		background_sprite.texture = black_texture
		background_sprite.scale = Vector2(1280, 720)
	if foreground_sprite:
		foreground_sprite.visible = false

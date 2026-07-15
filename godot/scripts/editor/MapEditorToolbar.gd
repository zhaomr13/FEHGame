class_name MapEditorToolbar
extends HBoxContainer

signal new_city_pressed
signal delete_city_pressed
signal save_pressed
signal back_pressed

@onready var new_btn: Button = $NewBtn
@onready var delete_btn: Button = $DeleteBtn
@onready var save_btn: Button = $SaveBtn
@onready var back_btn: Button = $BackBtn

func _ready():
	new_btn.pressed.connect(func(): new_city_pressed.emit())
	delete_btn.pressed.connect(func(): delete_city_pressed.emit())
	save_btn.pressed.connect(func(): save_pressed.emit())
	back_btn.pressed.connect(func(): back_pressed.emit())

func set_delete_enabled(enabled: bool):
	delete_btn.disabled = not enabled

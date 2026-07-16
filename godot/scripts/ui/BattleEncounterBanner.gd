class_name BattleEncounterBanner
extends CanvasLayer

@onready var banner_panel: Panel = $BannerPanel
@onready var title_label: Label = $BannerPanel/TitleLabel
@onready var attacker_color: ColorRect = $BannerPanel/AttackerColor
@onready var defender_color: ColorRect = $BannerPanel/DefenderColor
@onready var attacker_icon: TextureRect = $BannerPanel/AttackerIcon
@onready var defender_icon: TextureRect = $BannerPanel/DefenderIcon
@onready var skip_hint_label: Label = $BannerPanel/SkipHintLabel

const FactionColors = {
	"askr": Color(0.2, 0.6, 1.0),
	"embla": Color(0.8, 0.2, 0.2),
	"nifl": Color(0.2, 0.8, 0.8),
	"muspell": Color(0.9, 0.5, 0.1)
}

const DEFAULT_COLOR = Color(0.6, 0.6, 0.6)

func _ready():
	visible = false
	banner_panel.position.y = 100.0
	banner_panel.modulate = Color.TRANSPARENT

func show_encounter(attacker_name: String, defender_name: String, city_name: String, attacker_faction: String = "", defender_faction: String = ""):
	visible = true
	banner_panel.modulate = Color.WHITE
	title_label.text = "%s军 与 %s军 战于 %s" % [attacker_name, defender_name, city_name]
	attacker_color.color = FactionColors.get(attacker_faction, DEFAULT_COLOR)
	defender_color.color = FactionColors.get(defender_faction, DEFAULT_COLOR)
	if attacker_icon:
		attacker_icon.texture = GameConstants.get_faction_icon(attacker_faction)
	if defender_icon:
		defender_icon.texture = GameConstants.get_faction_icon(defender_faction)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_panel, "position:y", 0.0, 0.4).from(100.0)

func hide_banner():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(banner_panel, "modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property(banner_panel, "position:y", 100.0, 0.3)
	await tween.finished
	visible = false

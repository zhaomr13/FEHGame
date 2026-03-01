class_name WorldMapManager
extends Node2D

signal turn_ended

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var map_nodes: Dictionary = {}
var player_token: Node2D
var is_player_turn: bool = true

# World map backgrounds
const WORLD_BACKGROUNDS = {
    "world_map": "res://assets/world_map/backgrounds/world_map.png",  # Main map (201805.png)
    "occupation": "res://assets/world_map/backgrounds/occupation_map.png",
    "title": "res://assets/world_map/backgrounds/title_bg.png",
    "arena": "res://assets/world_map/backgrounds/arena_bg.png"
}

# Node configuration for 201805.png world map
# Coordinates based on 1280x720 viewport, adjust based on actual background size
const NODE_CONFIG = {
    "city_1": {"name": "北方要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(400, 150), "connections": ["city_3"]},
    "city_2": {"name": "西风村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(200, 280), "connections": ["city_3", "city_5"]},
    "city_3": {"name": "中央城", "type": GameConstants.NodeType.CITY, "pos": Vector2(450, 280), "connections": ["city_1", "city_2", "city_4", "city_8"]},
    "city_4": {"name": "东影城", "type": GameConstants.NodeType.CITY, "pos": Vector2(700, 280), "connections": ["city_3", "city_6"]},
    "city_5": {"name": "南海村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(150, 450), "connections": ["city_2", "city_7"]},
    "city_6": {"name": "东北要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(850, 200), "connections": ["city_4"]},
    "city_7": {"name": "河湾村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(300, 500), "connections": ["city_5", "city_8"]},
    "city_8": {"name": "南方城", "type": GameConstants.NodeType.CITY, "pos": Vector2(500, 480), "connections": ["city_3", "city_7", "city_9", "city_10"]},
    "city_9": {"name": "东岛村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(750, 500), "connections": ["city_8"]},
    "city_10": {"name": "帝都", "type": GameConstants.NodeType.CITY, "pos": Vector2(550, 600), "connections": ["city_8"]}
}

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_nodes_container: Node2D = $MapNodes

func _ready():
    GameManager.change_state(GameConstants.GameState.WORLD_MAP)
    setup_background()
    create_map_nodes()
    initialize_map()

func setup_background():
    """Setup the world map background (201805.png)"""
    if background_sprite:
        background_sprite.texture = load(WORLD_BACKGROUNDS["world_map"])
        # Center the background if it's larger than viewport
        var bg_size = background_sprite.texture.get_size()
        background_sprite.position = bg_size / 2

func create_map_nodes():
    """Create map nodes from NODE_CONFIG"""
    for node_id in NODE_CONFIG.keys():
        var config = NODE_CONFIG[node_id]
        var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
        node.node_id = node_id
        node.node_name = config.name
        node.node_type = config.type
        node.position = config.pos
        node.connections = config.connections
        map_nodes_container.add_child(node)

func initialize_map():
    for child in map_nodes_container.get_children():
        if child is MapNode:
            map_nodes[child.node_id] = child
            child.node_clicked.connect(_on_node_clicked)

func _on_node_clicked(node: MapNode):
    if not is_player_turn:
        return

    var current_node = map_nodes.get(current_node_id)
    if current_node and current_node.connections.has(node.node_id):
        move_to_node(node)

func move_to_node(target_node: MapNode):
    current_node_id = target_node.node_id
    target_node.explore()

    if target_node.node_type == GameConstants.NodeType.BATTLE:
        trigger_battle(target_node)
    elif target_node.node_type == GameConstants.NodeType.CITY:
        show_city_menu(target_node)

func trigger_battle(node: MapNode):
    var enemy_units = generate_enemy_army(node)

    # Select battle background based on node type and terrain
    var battle_bg = select_battle_background(node)

    # Start battle with background info
    GameManager.battle_started_with_background.emit(GameManager.player_army, enemy_units, battle_bg)
    GameManager.start_battle(GameManager.player_army, enemy_units)

func select_battle_background(node: MapNode) -> String:
    """Select appropriate battle background based on node type"""
    match node.node_type:
        GameConstants.NodeType.CITY:
            return "inside"
        GameConstants.NodeType.FORT:
            return "brave_attack"
        GameConstants.NodeType.VILLAGE:
            return "plain_forest"
        _:
            # Random outdoor battle
            var outdoor_bgs = ["plain", "forest", "river", "plain_forest"]
            return outdoor_bgs[randi() % outdoor_bgs.size()]

func generate_enemy_army(node: MapNode) -> Array[CharacterData]:
    # Generate enemy force based on node
    var enemies: Array[CharacterData] = []
    # TODO: Generate appropriate enemies
    return enemies

func get_total_soldiers() -> int:
    var total = 0
    for char in GameManager.player_army:
        total += char.soldiers
    return total

func end_player_turn():
    is_player_turn = false
    turn_ended.emit()
    process_enemy_turn()

func process_enemy_turn():
    await get_tree().create_timer(1.0).timeout
    turn_count += 1
    is_player_turn = true

func show_city_menu(node: MapNode):
    # TODO: Show city options UI
    pass

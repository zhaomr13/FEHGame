class_name PlanningPhaseController
extends Node2D

signal planning_phase_started
signal planning_ended
signal plans_cleared
signal city_opened(node: MapNode)
signal formation_opened
signal deploy_requested

var is_dragging_plan: bool = false
var drag_start_army: Army = null
var planning_ui: Control = null

@onready var map_data: MapDataManager = $"../MapDataManager"
@onready var army_mgr: WorldMapArmyManager = $"../WorldMapArmyManager"
@onready var ui: CanvasLayer = $"../WorldMapUI"

func setup_planning_ui():
	planning_ui = Control.new()
	planning_ui.name = "PlanningUI"
	planning_ui.visible = false

	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()
	hbox.name = "ButtonContainer"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var end_planning_btn = Button.new()
	end_planning_btn.name = "EndPlanningButton"
	end_planning_btn.text = "End Planning Phase"
	end_planning_btn.custom_minimum_size = Vector2(200, 50)
	end_planning_btn.pressed.connect(_on_end_planning_pressed)

	var cancel_plan_btn = Button.new()
	cancel_plan_btn.name = "CancelPlanButton"
	cancel_plan_btn.text = "Clear All Plans"
	cancel_plan_btn.custom_minimum_size = Vector2(150, 50)
	cancel_plan_btn.pressed.connect(_on_clear_plans_pressed)

	hbox.add_child(end_planning_btn)
	hbox.add_child(cancel_plan_btn)
	panel.add_child(hbox)
	planning_ui.add_child(panel)

	ui.add_child(planning_ui)

func start_planning_phase():
	for army in army_mgr.player_armies:
		army.clear_plan()

	if planning_ui:
		planning_ui.visible = true

	planning_phase_started.emit()

func _on_end_planning_pressed():
	if planning_ui:
		planning_ui.visible = false
	planning_ended.emit()

func _on_clear_plans_pressed():
	for army in army_mgr.player_armies:
		army.clear_plan()
	plans_cleared.emit()

func handle_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and is_dragging_plan:
				_end_drag_selection()

func _end_drag_selection():
	is_dragging_plan = false

	var target = army_mgr.get_army_at_position(get_global_mouse_position())
	if target and target.army_type == Army.ArmyType.ENEMY:
		if army_mgr.selected_army:
			army_mgr.selected_army.set_attack_plan(target)
	elif target and target.army_type != Army.ArmyType.ENEMY:
		army_mgr.set_selected_army(target)

func on_army_clicked(army: Army):
	if army.army_type != Army.ArmyType.PLAYER_MAIN and army.army_type != Army.ArmyType.PLAYER_SQUAD:
		if army_mgr.selected_army:
			army_mgr.selected_army.set_attack_plan(army)
		return

	_start_drag_plan(army)

func _start_drag_plan(army: Army):
	army_mgr.set_selected_army(army)
	is_dragging_plan = true
	drag_start_army = army

func on_node_clicked(node: MapNode):
	if is_dragging_plan:
		is_dragging_plan = false
		if army_mgr.selected_army and army_mgr.selected_army.current_city_id != node.node_id:
			var can_move = map_data.can_move_to(army_mgr.selected_army.current_city_id, node.node_id)
			if can_move:
				var path = map_data.find_path(army_mgr.selected_army.current_city_id, node.node_id)
				if not path.is_empty():
					army_mgr.selected_army.set_planning_move(node.node_id, path, node.position + Vector2(20, -20))
		return

	if not army_mgr.selected_army:
		if map_data.NODE_CONFIG[node.node_id].faction == $"..".current_faction:
			city_opened.emit(node)
		return

	var can_move = map_data.can_move_to(army_mgr.selected_army.current_city_id, node.node_id)
	if can_move:
		var path = map_data.find_path(army_mgr.selected_army.current_city_id, node.node_id)
		if not path.is_empty():
			army_mgr.selected_army.set_planning_move(node.node_id, path, node.position + Vector2(20, -20))

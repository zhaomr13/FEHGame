class_name ArmyManagePanel
extends Control

signal saved(armies: Array, unassigned: Array, army_squad_indices: Array)
signal cancelled

var _armies: Array[Array] = []
var _army_squad_indices: Array[int] = []  # parallel to _armies: original squad_index, -1 = new
var _unassigned: Array[CharacterData] = []
var _selected_army_idx: int = -1       # -1 = unassigned, >=0 = army index
var _garrison_city_id: String = ""
var _checked: Dictionary = {}  # idx -> true for ticked character checkboxes

const MAX_ARMIES: int = 20
const MAX_PER_ARMY: int = 6
const UNASSIGNED_IDX: int = -1

@onready var army_list: VBoxContainer = $Panel/VBox/HBox/Left/ScrollArmy/ArmyList
@onready var unassigned_btn: Button = $Panel/VBox/HBox/Left/UnassignedBtn
@onready var char_list: VBoxContainer = $Panel/VBox/HBox/Center/Scroll/CharList
@onready var char_title: Label = $Panel/VBox/HBox/Center/CharTitle
@onready var move_target: OptionButton = $Panel/VBox/HBox/Right/MoveTarget
@onready var split_btn: Button = $Panel/VBox/HBox/Right/SplitBtn
@onready var move_btn: Button = $Panel/VBox/HBox/Right/MoveBtn
@onready var disband_btn: Button = $Panel/VBox/HBox/Right/DisbandBtn
@onready var create_btn: Button = $Panel/VBox/HBox/Left/CreateBtn
@onready var save_btn: Button = $Panel/VBox/Bottom/SaveBtn
@onready var cancel_btn: Button = $Panel/VBox/Bottom/CancelBtn
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var msg_label: Label = $Panel/VBox/MsgLabel


func setup(armies: Array, unassigned: Array, city_name: String, city_id: String, squad_indices: Array[int] = []):
	_armies = []
	_army_squad_indices = []
	for i in range(armies.size()):
		_armies.append(armies[i].duplicate())
		_army_squad_indices.append(squad_indices[i] if i < squad_indices.size() else -1)
	_unassigned = unassigned.duplicate()
	_garrison_city_id = city_id
	title_label.text = "%s - 驻军管理" % city_name
	_selected_army_idx = -1
	_refresh_all()
	_show_msg("")


func _ready():
	create_btn.pressed.connect(_on_create)
	split_btn.pressed.connect(_on_split)
	move_btn.pressed.connect(_on_move)
	disband_btn.pressed.connect(_on_disband)
	save_btn.pressed.connect(_on_save)
	cancel_btn.pressed.connect(_on_cancel)
	unassigned_btn.pressed.connect(_on_unassigned_selected)
	visible = false


func _refresh_all():
	_refresh_army_list()
	_refresh_move_targets()
	if _selected_army_idx >= 0 and _selected_army_idx < _armies.size():
		_refresh_char_list_army()
	elif _selected_army_idx == UNASSIGNED_IDX:
		_refresh_char_list_unassigned()
	else:
		_clear_char_list()
	_update_buttons()


func _refresh_army_list():
	for child in army_list.get_children():
		army_list.remove_child(child)
		child.queue_free()

	for i in range(_armies.size()):
		var army = _armies[i]
		var btn = Button.new()
		btn.text = "第%d队 (%d/%d)" % [i + 1, army.size(), MAX_PER_ARMY]
		btn.custom_minimum_size = Vector2(160, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (i == _selected_army_idx)
		var idx = i
		btn.pressed.connect(func(): _on_army_selected(idx))
		army_list.add_child(btn)

	unassigned_btn.button_pressed = (_selected_army_idx == UNASSIGNED_IDX)
	unassigned_btn.text = "未分配 (%d)" % _unassigned.size()


func _refresh_char_list_army():
	_clear_char_list()
	char_title.text = "角色"
	var army = _armies[_selected_army_idx]
	if army.is_empty():
		var label = Label.new()
		label.text = "无角色"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.6, 0.6, 0.6)
		char_list.add_child(label)
		return

	var all_cb = CheckBox.new()
	all_cb.text = "全选"
	all_cb.toggled.connect(_on_select_all)
	all_cb.name = "__all__"
	char_list.add_child(all_cb)

	for i in range(army.size()):
		var chara = army[i]
		var cb = CheckBox.new()
		cb.text = chara.character_name
		cb.name = str(i)
		var ci = i
		cb.toggled.connect(func(pressed: bool): _on_char_toggled(ci, pressed))
		char_list.add_child(cb)


func _refresh_char_list_unassigned():
	_clear_char_list()
	char_title.text = "未分配角色"
	if _unassigned.is_empty():
		var label = Label.new()
		label.text = "无未分配角色"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.6, 0.6, 0.6)
		char_list.add_child(label)
		return

	var all_cb = CheckBox.new()
	all_cb.text = "全选"
	all_cb.toggled.connect(_on_select_all)
	all_cb.name = "__all__"
	char_list.add_child(all_cb)

	for i in range(_unassigned.size()):
		var chara = _unassigned[i]
		var cb = CheckBox.new()
		cb.text = chara.character_name
		var ci = i
		cb.name = str(i)
		cb.toggled.connect(func(pressed: bool): _on_char_toggled(ci, pressed))
		char_list.add_child(cb)


func _clear_char_list():
	_checked.clear()
	for child in char_list.get_children():
		char_list.remove_child(child)
		child.queue_free()
	char_title.text = ""


func _refresh_move_targets():
	move_target.clear()
	if _selected_army_idx == UNASSIGNED_IDX:
		# Moving FROM unassigned TO an army
		for i in range(_armies.size()):
			move_target.add_item("第%d队" % (i + 1))
			move_target.set_item_metadata(i, i)
	else:
		# Moving FROM an army TO another army, or TO unassigned
		for i in range(_armies.size()):
			if i != _selected_army_idx:
				move_target.add_item("第%d队" % (i + 1))
				move_target.set_item_metadata(move_target.item_count - 1, i)
		move_target.add_item("→ 未分配")
		move_target.set_item_metadata(move_target.item_count - 1, UNASSIGNED_IDX)
	if move_target.item_count > 0:
		move_target.select(0)


func _update_buttons():
	var has_army = _selected_army_idx >= 0 and _selected_army_idx < _armies.size()
	var has_selection = has_army or _selected_army_idx == UNASSIGNED_IDX

	split_btn.disabled = not has_army
	move_btn.disabled = not has_selection
	move_target.disabled = not has_selection
	disband_btn.disabled = not has_army
	create_btn.disabled = _armies.size() >= MAX_ARMIES


func _on_char_toggled(idx: int, pressed: bool):
	if pressed:
		_checked[idx] = true
	else:
		_checked.erase(idx)
	_update_buttons()

func _get_checked_indices() -> Array[int]:
	var result: Array[int] = []
	for idx in _checked.keys():
		result.append(idx)
	return result


func _on_select_all(pressed: bool):
	_checked.clear()
	for child in char_list.get_children():
		if child is CheckBox and child.name != "__all__":
			child.button_pressed = pressed
			if pressed:
				_checked[child.name.to_int()] = true
	_update_buttons()


func _on_army_selected(idx: int):
	_selected_army_idx = clamp(idx, -1, _armies.size() - 1)
	_show_msg("")
	_refresh_all()


func _on_unassigned_selected():
	_selected_army_idx = UNASSIGNED_IDX
	_show_msg("")
	_refresh_all()




func _on_create():
	if _armies.size() >= MAX_ARMIES:
		return
	_armies.append([])
	_army_squad_indices.append(-1)
	_selected_army_idx = _armies.size() - 1
	_show_msg("")
	_refresh_all()


func _on_split():
	if _selected_army_idx < 0 or _selected_army_idx >= _armies.size():
		return
	var indices = _get_checked_indices()
	if indices.is_empty() or indices.size() >= _armies[_selected_army_idx].size():
		_show_msg("请选择1个以上角色（不能全选）")
		return
	if _armies.size() >= MAX_ARMIES:
		_show_msg("军队数量已达上限（%d）" % MAX_ARMIES)
		return

	var src = _armies[_selected_army_idx]
	var new_army: Array = []
	indices.sort()
	indices.reverse()
	for i in indices:
		new_army.append(src[i])
		src.remove_at(i)

	_armies.append(new_army)
	_army_squad_indices.append(-1)
	_selected_army_idx = _armies.size() - 1
	_show_msg("已拆分出新军队：第%d队 (%d人)" % [_armies.size(), new_army.size()])
	_refresh_all()


func _on_move():
	var indices = _get_checked_indices()
	if indices.is_empty():
		_show_msg("请先选择角色")
		return

	var sel_idx = move_target.get_selected()
	if sel_idx < 0:
		_show_msg("请选择目标")
		return
	var target = move_target.get_item_metadata(sel_idx)

	if _selected_army_idx == UNASSIGNED_IDX:
		# Moving from unassigned to army
		if target < 0 or target >= _armies.size():
			_show_msg("无效目标")
			return
		var dst = _armies[target]
		if dst.size() + indices.size() > MAX_PER_ARMY:
			_show_msg("目标军队已满（最多%d人）" % MAX_PER_ARMY)
			return
		indices.sort()
		indices.reverse()
		for i in indices:
			dst.append(_unassigned[i])
			_unassigned.remove_at(i)
		_show_msg("已将%d人移入第%d队" % [indices.size(), target + 1])

	elif target == UNASSIGNED_IDX:
		# Moving from army to unassigned
		var src = _armies[_selected_army_idx]
		indices.sort()
		indices.reverse()
		for i in indices:
			_unassigned.append(src[i])
			src.remove_at(i)
		if src.is_empty():
			_armies.remove_at(_selected_army_idx)
			_army_squad_indices.remove_at(_selected_army_idx)
			_show_msg("军队已空，自动解散")
			if _selected_army_idx >= _armies.size():
				_selected_army_idx = max(0, _armies.size() - 1)
			if _armies.is_empty():
				_selected_army_idx = UNASSIGNED_IDX
		else:
			_show_msg("已将%d人移入未分配" % indices.size())

	else:
		# Moving from army to army
		if target < 0 or target >= _armies.size():
			_show_msg("无效目标")
			return
		var src = _armies[_selected_army_idx]
		var dst = _armies[target]
		if dst.size() + indices.size() > MAX_PER_ARMY:
			_show_msg("目标军队已满（最多%d人）" % MAX_PER_ARMY)
			return

		indices.sort()
		indices.reverse()
		for i in indices:
			dst.append(src[i])
			src.remove_at(i)

		if src.is_empty():
			_armies.remove_at(_selected_army_idx)
			_army_squad_indices.remove_at(_selected_army_idx)
			_show_msg("源军队已空，自动解散")
			if _selected_army_idx >= _armies.size():
				_selected_army_idx = max(0, _armies.size() - 1)
			if _armies.is_empty():
				_selected_army_idx = UNASSIGNED_IDX
		else:
			_show_msg("已将%d人移入第%d队" % [indices.size(), target + 1])

	_refresh_all()


func _on_disband():
	if _selected_army_idx < 0 or _selected_army_idx >= _armies.size():
		return

	var count = _armies[_selected_army_idx].size()
	for chara in _armies[_selected_army_idx]:
		_unassigned.append(chara)
	_armies.remove_at(_selected_army_idx)
	_army_squad_indices.remove_at(_selected_army_idx)
	_show_msg("已解散第%d队，%d人变为未分配" % [_selected_army_idx + 1, count])
	if _selected_army_idx >= _armies.size():
		_selected_army_idx = max(0, _armies.size() - 1)
	if _armies.is_empty():
		_selected_army_idx = UNASSIGNED_IDX
	_refresh_all()


func _on_save():
	var armies_out: Array = []
	var indices_out: Array[int] = []
	for i in range(_armies.size()):
		if not _armies[i].is_empty():
			armies_out.append(_armies[i].duplicate())
			indices_out.append(_army_squad_indices[i])
	visible = false
	saved.emit(armies_out, _unassigned.duplicate(), indices_out)


func _on_cancel():
	visible = false
	cancelled.emit()


func _show_msg(text: String):
	if msg_label:
		msg_label.text = text

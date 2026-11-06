extends Control

var session: Node

var player: CharacterBody2D
var controls: Control
var inventory: RefCounted
var modal: PanelContainer
var content: VBoxContainer
var talk_button: Label
var backpack: Control
var nearby: Node2D
var active_npc: StaticBody2D
var line_index := 0
var mode := ""
var message := ""
var toast: Label
var toast_time := 0.0
var quest_label: Label
var tool_button: Button
var overlay: ColorRect
var dialogue_finished := false

func _ready() -> void:
	session = get_node("/root/GameSession")
	inventory = session.inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", load(ProjectSettings.get_setting("gui/theme/custom_font")))
	add_theme_font_size_override("font_size", 20)
	var theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("202f3bef")
	panel.border_color = Color("648d8c")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	theme.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("42696b") if state in ["hover", "pressed"] else Color("2b444f")
		style.set_corner_radius_all(8)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		theme.set_stylebox(state, "Button", style)
	self.theme = theme
	var toolbar := HBoxContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.position = Vector2(-465, 22)
	toolbar.add_theme_constant_override("separation", 10)
	add_child(toolbar)
	_toolbar_button(toolbar, "背包 [B]", toggle_bag)
	tool_button = _toolbar_button(toolbar, "", _toolbar_tool)
	_toolbar_button(toolbar, "菜单", show_menu)
	_update_tool(session.tool)
	talk_button = Label.new()
	talk_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	talk_button.position = Vector2(-230, -58)
	talk_button.size = Vector2(460, 32)
	talk_button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talk_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talk_button.modulate = Color("e8d49e")
	add_child(talk_button)
	quest_label = Label.new()
	quest_label.position = Vector2(25, 122)
	quest_label.add_theme_font_size_override("font_size", 17)
	add_child(quest_label)
	toast = Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-360, 90)
	toast.size = Vector2(720, 60)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.modulate = Color("ffe3a1")
	add_child(toast)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.05, 0.08, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	modal = PanelContainer.new()
	add_child(modal)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	modal.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "关闭 ×"
	close.custom_minimum_size = Vector2(100, 45)
	close.pressed.connect(close_modal)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	backpack = preload("res://scripts/game/BackpackUI.gd").new()
	backpack.player = player
	add_child(backpack)
	backpack.closed.connect(close_modal)
	backpack.status.connect(_notify)
	controls.ui_context = self
	controls.action_requested.connect(_handle_action)
	controls.cancel_requested.connect(cancel_interaction)
	get_viewport().size_changed.connect(_layout)
	_layout()
	modal.hide()
	overlay.hide()
	inventory.changed.connect(_inventory_changed)
	session.notified.connect(_notify)
	session.tool_changed.connect(_update_tool)
	session.quest_changed.connect(_update_quest)
	session.scene_changing.connect(_lock_for_travel)
	_update_quest()
	_notify("青禾村：与阿远交谈接取委托。切换右下模式，E交互 / F劳动 / J战斗。" if session.world == "village" else "薄雾林地：注意史莱姆，西侧路口可返回村庄。")

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var dimensions := Vector2(minf(680, viewport.x - 40), minf(560, viewport.y - 60))
	modal.position = (viewport - dimensions) / 2
	modal.size = dimensions

func _toolbar_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(125, 52)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	toast_time -= delta
	toast.visible = toast_time > 0
	nearby = null
	var distance := 105.0
	for object in get_tree().get_nodes_in_group("interactables"):
		var candidate: float = player.global_position.distance_to(object.global_position)
		if candidate < distance:
			distance = candidate
			nearby = object
	talk_button.visible = nearby != null and mode == ""
	if nearby:
		talk_button.text = nearby.display_name + (" · 按 E" if session.action_mode == 0 else " · 按 F 使用工具" if session.action_mode == 1 else "")

func _input(event: InputEvent) -> void:
	if session.changing: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B:
				toggle_bag()
				get_viewport().set_input_as_handled()
			KEY_E:
				if mode == "" and session.action_mode == 0: interact()
				elif mode == "dialogue": advance_dialogue()
				get_viewport().set_input_as_handled()
			KEY_G:
				if mode == "" and session.action_mode == 0: open_gift()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				if mode == "" and session.action_mode == 1: session.cycle_tool()
				get_viewport().set_input_as_handled()
			KEY_M:
				if mode == "": session.set_action_mode((session.action_mode + 1) % 3)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if mode == "bag" and backpack.confirm_panel.visible: backpack.cancel_discard()
				elif mode == "": show_menu()
				else: close_modal()
				get_viewport().set_input_as_handled()

func _lock_for_travel() -> void:
	player.input_locked = true
	controls.input_locked = true
	controls.reset_stick()

func _open(value: String) -> void:
	backpack.hide()
	mode = value
	modal.show()
	overlay.show()
	_lock_for_travel()
	player.touch_direction = Vector2.ZERO

func close_modal() -> void:
	backpack.hide()
	backpack.cancel_discard()
	mode = ""
	modal.hide()
	overlay.hide()
	player.input_locked = false
	controls.input_locked = false
	active_npc = null

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _text(value: String, heading := false) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26 if heading else 19)
	content.add_child(label)

func _button(value: String, action: Callable, icon := "") -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 50
	if icon != "":
		button.icon = preload("res://scripts/game/SproutArt.gd").icon(icon)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
	button.pressed.connect(action)
	content.add_child(button)

func toggle_bag() -> void:
	if mode == "bag":
		close_modal()
		return
	_open("bag")
	modal.hide()
	backpack.open_bag()

func show_bag() -> void:
	backpack.refresh()

func use_potion() -> void:
	if inventory.use_item("potion", player): _notify("已治疗，恢复生命。")
	else: _notify("生命已满或药水不足。")
	backpack.refresh()

func _inventory_changed() -> void:
	_update_quest()

func _toolbar_tool() -> void:
	if session.action_mode != 1: session.set_action_mode(1)
	else: session.cycle_tool()

func _update_tool(tool: String) -> void:
	tool_button.text = session.TOOL_NAMES.get(tool, "空手") + (" · 收起" if session.tool_stowed else "")
	tool_button.icon = preload("res://scripts/game/SproutArt.gd").icon(tool) if tool != "" else null

func _handle_action(index: int) -> void:
	if session.action_mode == 0:
		match index:
			0: interact()
			1: open_gift()
			2: cancel_interaction()
	elif session.action_mode == 1:
		match index:
			0: player.use_tool()
			1: session.cycle_tool()
			2: session.stow_tool()

func cancel_interaction() -> void:
	if mode != "": close_modal()
	controls.reset_stick()
	_notify("已取消 / 离开当前交互。")

func open_gift() -> void:
	var target: Node2D
	var distance := 110.0
	for npc in get_tree().get_nodes_in_group("villagers"):
		var candidate: float = player.global_position.distance_to(npc.global_position)
		if candidate < distance:
			target = npc
			distance = candidate
	if target == null:
		_notify("靠近 NPC 后再赠礼。")
		return
	_open("bag")
	modal.hide()
	backpack.open_bag(target)

func _update_quest() -> void:
	if session.quest == 0:
		quest_label.text = "委托：与村里的巡林员阿远交谈\n" + ("东侧路口 → 薄雾林地" if session.world == "village" else "西侧路口 → 青禾村")
	elif session.quest == 1:
		quest_label.text = "修缮委托 · 木材 %d/3  矿石 %d/2  草药 %d/2\n集齐后找阿远交付" % [inventory.stacks.wood, inventory.stacks.stone, inventory.stacks.herb]
	else:
		quest_label.text = "修缮委托已完成！\n继续探索、采集、炼药与战斗。"

func _notify(value: String) -> void:
	toast.text = value
	toast_time = 5

func interact() -> void:
	if nearby == null or mode != "": return
	if nearby.is_in_group("villagers"): start_talk()
	elif nearby.has_method("interact"): nearby.interact(player)

func start_talk() -> void:
	if nearby == null or not nearby.is_in_group("villagers"): return
	active_npc = nearby
	line_index = 0
	dialogue_finished = false
	_open("dialogue")
	show_dialogue()

func show_dialogue() -> void:
	_clear()
	_text(active_npc.npc_name, true)
	_text(active_npc.lines[line_index])
	_text("%d / %d" % [line_index + 1, active_npc.lines.size()])
	_button("继续 [E]" if line_index < active_npc.lines.size() - 1 else "回应 [E]", advance_dialogue)
	_button("稍后再聊 [Esc]", close_modal)

func advance_dialogue() -> void:
	if active_npc == null: return
	if dialogue_finished:
		close_modal()
		return
	line_index += 1
	if line_index < active_npc.lines.size():
		show_dialogue()
		return
	dialogue_finished = true
	_clear()
	_text(active_npc.npc_name, true)
	if not session.flags.get("gift_" + active_npc.npc_id, false):
		session.flags["gift_" + active_npc.npc_id] = true
		inventory.add_item(active_npc.gift, 1)
		_text("初次见面礼：" + inventory.ITEMS[active_npc.gift].name + " × 1")
	if active_npc.npc_id == "ranger":
		if session.quest == 0:
			session.quest = 1
			session.quest_changed.emit()
			_text("已接取修缮委托：木材3、矿石2、草药2。奖励50金币和2瓶药水。")
		elif session.quest == 1:
			_button("交付委托材料", _submit_quest)
		else:
			_text("谢谢你的帮助！村子的修缮工程可以开始了。")
		_button("购买药水 · 10金币", _trade.bind({"coin": 10}, {"potion": 1}))
	else:
		_text("有草药的话，我随时可以为你炼药。")
		_button("炼制药水 · 2草药 → 1药水", _trade.bind({"herb": 2}, {"potion": 1}))
	_button("结束交谈 [E]", close_modal)
	session.save()

func _trade(cost: Dictionary, reward: Dictionary) -> void:
	if inventory.exchange(cost, reward): _notify("交易成功，物品已放入背包。")
	else: _notify("材料或金币不足，或物品已达上限。")

func _submit_quest() -> void:
	if session.complete_quest(): close_modal()

func show_menu() -> void:
	_open("menu")
	_clear()
	_text("青禾物语 / MEADOW JOURNEY", true)
	_text("WASD 移动 · J 攻击 · K 冲刺 · L 震波 · H 治疗\nM 切换模式 · E 交互 / G 赠礼 · F 劳动 / Tab 换工具 · B 背包\n手机点击治疗按钮上方的模式按钮，切换交互、劳动、战斗。")
	_text("采集：树与矿石需要使用工具两次，草药一次。资源30秒恢复。\n角色倒下会返回村庄。宝箱、礼物、任务和背包会保存。")
	_button("继续游戏", close_modal)
	_button("保存进度", _save_progress)
	_text("部分美术：Sprout Lands — Cup Nooble（Basic Pack）")
	_button("返回登录", _return_login)
	_button("返回标题", _return_title)

func _save_progress() -> void:
	session.health = player.health
	session.save()
	_notify("进度已保存。")

func _return_title() -> void:
	_save_progress()
	get_tree().change_scene_to_file("res://scenes/game/Start.tscn")

func _return_login() -> void:
	_save_progress()
	get_tree().change_scene_to_file("res://scenes/auth/Login.tscn")

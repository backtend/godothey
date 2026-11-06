extends Control

signal closed
signal status(text: String)
const COLS := 10
const ROWS := 5
const Art = preload("res://scripts/game/SproutArt.gd")
var session: Node
var player: CharacterBody2D
var inventory: RefCounted
var panel: PanelContainer
var grid: GridContainer
var details: PanelContainer
var detail_content: VBoxContainer
var action_button: Button
var discard_button: Button
var footer: Label
var capacity_label: Label
var slot_buttons: Array[Button] = []
var selected_id := ""
var recipient: Node2D
var confirm_shade: ColorRect
var confirm_panel: PanelContainer
var confirm_text: Label
var discard_amount: SpinBox
var pending_id := ""
var cell_size := 67.0
var right_space: Control
var content_root: VBoxContainer

func _ready() -> void:
	session = get_node("/root/GameSession")
	inventory = session.inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("172a38"), Color("b69a62"), 16))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	content_root = VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 16)
	margin.add_child(content_root)
	var header := HBoxContainer.new()
	content_root.add_child(header)
	var title := Label.new()
	title.text = "行 囊"
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color("f2dfad")
	header.add_child(title)
	capacity_label = Label.new()
	capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacity_label.add_theme_font_size_override("font_size", 17)
	header.add_child(capacity_label)
	var close := _button("关闭 ×", close_bag)
	close.custom_minimum_size = Vector2(100, 46)
	header.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	var rule := Label.new()
	rule.text = "物品栏  /  10列 × 5行"
	rule.modulate = Color("92b0be")
	rule.add_theme_font_size_override("font_size", 16)
	left.add_child(rule)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	left.add_child(grid)
	for i in range(COLS * ROWS):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(select_slot.bind(i))
		grid.add_child(button)
		slot_buttons.append(button)
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 12
		icon.offset_top = 9
		icon.offset_right = -12
		icon.offset_bottom = -13
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.position = Vector2(-56, -25)
		count.size = Vector2(49, 21)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 16)
		count.add_theme_color_override("font_outline_color", Color("101c26"))
		count.add_theme_constant_override("outline_size", 5)
		button.add_child(count)
	right_space = Control.new()
	right_space.custom_minimum_size.x = 270
	right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right_space)
	var hint := Label.new()
	hint.text = "选择物品\n查看介绍与可用操作"
	hint.position = Vector2(25, 120)
	hint.modulate = Color("72909c")
	right_space.add_child(hint)
	details = PanelContainer.new()
	details.add_theme_stylebox_override("panel", _box(Color("223b49"), Color("d3b67b"), 10))
	details.custom_minimum_size.x = 270
	right_space.add_child(details)
	var detail_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: detail_margin.add_theme_constant_override("margin_" + side, 17)
	details.add_child(detail_margin)
	detail_content = VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 13)
	detail_margin.add_child(detail_content)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	content_root.add_child(footer_row)
	footer = Label.new()
	footer.text = "点击图标查看详情 · 物品自动保存"
	footer.add_theme_font_size_override("font_size", 16)
	footer.modulate = Color("9cb6c1")
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(footer)
	discard_button = _button("丢弃", request_discard)
	discard_button.custom_minimum_size = Vector2(118, 48)
	footer_row.add_child(discard_button)
	var sort_button := _button("整理", sort_bag)
	sort_button.custom_minimum_size = Vector2(118, 48)
	footer_row.add_child(sort_button)
	_build_confirmation()
	get_viewport().size_changed.connect(_layout)
	inventory.changed.connect(refresh)
	_layout()
	hide()

func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.pressed.connect(callback)
	return button

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var width := minf(1160, viewport.x - 40)
	cell_size = floorf((width - 44 - 270 - 22 - 63) / COLS)
	cell_size = clampf(cell_size, 38, 76)
	for button in slot_buttons: button.custom_minimum_size = Vector2(cell_size, cell_size)
	var height := minf(640, viewport.y - 40)
	panel.position = (viewport - Vector2(width, height)) * 0.5
	panel.size = Vector2(width, height)
	confirm_panel.position = (viewport - Vector2(460, 300)) * 0.5
	confirm_panel.size = Vector2(460, 300)
	call_deferred("_position_details")

func open_bag(target: Node2D = null) -> void:
	recipient = target
	footer.text = "选择物品并点击赠礼 · 每次赠送1件" if is_instance_valid(target) else "点击图标查看详情 · 物品自动保存"
	selected_id = ""
	pending_id = ""
	confirm_shade.hide()
	confirm_panel.hide()
	show()
	refresh()

func close_bag() -> void:
	confirm_shade.hide()
	confirm_panel.hide()
	recipient = null
	hide()
	closed.emit()

func refresh() -> void:
	if not is_instance_valid(grid): return
	inventory._sync_slots()
	var used := 0
	for i in range(COLS * ROWS):
		var id: String = inventory.slots[i]
		var occupied := id != ""
		var button := slot_buttons[i]
		var icon: TextureRect = button.get_node("ItemIcon")
		var count: Label = button.get_node("Count")
		icon.texture = Art.icon(id) if occupied else null
		count.text = str(inventory.count(id)) if occupied else ""
		button.tooltip_text = str(inventory.ITEMS[id].name) if occupied else "空格子"
		var selected := occupied and id == selected_id
		var border := Color("e4c480") if selected else (Color("497d94") if occupied else Color("304856"))
		var base := Color("325465") if selected else Color("1d3341")
		button.add_theme_stylebox_override("normal", _box(base, border, 7))
		button.add_theme_stylebox_override("hover", _box(Color("2a4857"), Color("d3b67b"), 7))
		button.add_theme_stylebox_override("pressed", _box(Color("3b5e6c"), Color("f5df9d"), 7))
		if occupied: used += 1
	capacity_label.text = "%d / 50 格  ·  生命 %d  体力 %d" % [used, player.health, player.energy]
	if is_instance_valid(recipient): capacity_label.text = "赠礼给 " + recipient.npc_name + "  ·  %d / 50 格" % used
	discard_button.disabled = selected_id == "" or inventory.count(selected_id) <= 0
	if inventory.count(selected_id) <= 0: selected_id = ""
	_show_details()

func select_slot(index: int) -> void:
	if confirm_panel.visible: return
	selected_id = inventory.slots[index]
	refresh()

func _label(text: String, size := 18, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 234
	detail_content.add_child(label)
	return label

func _show_details() -> void:
	action_button = null
	for child in detail_content.get_children():
		detail_content.remove_child(child)
		child.queue_free()
	details.visible = selected_id != ""
	if selected_id == "": return
	var item: Dictionary = inventory.ITEMS[selected_id]
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	detail_content.add_child(preview_row)
	var preview := TextureRect.new()
	preview.texture = Art.icon(selected_id)
	preview.custom_minimum_size = Vector2(58, 58)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_row.add_child(preview)
	var title := Label.new()
	title.text = item.name
	title.add_theme_font_size_override("font_size", 23)
	title.modulate = Color("f1d59d")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 162
	preview_row.add_child(title)
	_label("%s  ·  持有 %d" % [item.category, inventory.count(selected_id)], 15, Color("a8c9d3"))
	_label(item.description, 18)
	if selected_id == session.equipment_id or (selected_id == session.tool and not session.tool_stowed):
		_label("已装备", 16, Color("96d8ae"))
	var action := str(item.get("action", ""))
	if is_instance_valid(recipient): action = "赠礼"
	if action != "":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		detail_content.add_child(row)
		action_button = _button(action, activate_selected)
		action_button.custom_minimum_size.x = 118
		action_button.disabled = is_instance_valid(recipient) and not item.get("gift", false)
		row.add_child(action_button)
	call_deferred("_position_details")

func _position_details() -> void:
	if selected_id == "" or not is_instance_valid(details): return
	var index: int = inventory.slots.find(selected_id)
	var row := int(index / COLS)
	var wanted := 30.0 + row * (cell_size + 7)
	details.position = Vector2(0, minf(wanted, maxf(0, right_space.size.y - details.size.y)))
	details.size.x = right_space.size.x

func activate_selected() -> void:
	if selected_id == "" or inventory.count(selected_id) <= 0: return
	var id := selected_id
	var item: Dictionary = inventory.ITEMS[id]
	if is_instance_valid(recipient):
		if player.global_position.distance_to(recipient.global_position) > 110:
			set_message("距离太远，无法赠礼。")
			return
		if recipient.receive_gift(id): set_message("已赠送 " + item.name + " × 1")
		else: set_message("这件物品不能赠送。")
	elif item.get("action", "") == "装备":
		if session.equip_item(id): set_message("已装备 " + item.name)
	elif inventory.use_item(id, player):
		set_message(("已治疗" if item.action == "治疗" else "已食用") + "：" + item.name)
	else:
		set_message("当前无需补充，物品未消耗。")
	refresh()

func set_message(text: String) -> void:
	footer.text = text
	status.emit(text)

func sort_bag() -> void:
	inventory.sort_items()
	set_message("已按类型、工具顺序与名称整理。")
	refresh()

func _build_confirmation() -> void:
	confirm_shade = ColorRect.new()
	confirm_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_shade.color = Color(0.01, 0.02, 0.03, 0.78)
	add_child(confirm_shade)
	confirm_panel = PanelContainer.new()
	confirm_panel.add_theme_stylebox_override("panel", _box(Color("243541"), Color("d5a475"), 12))
	add_child(confirm_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	confirm_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	confirm_text = Label.new()
	confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(confirm_text)
	discard_amount = SpinBox.new()
	discard_amount.min_value = 1
	discard_amount.step = 1
	discard_amount.custom_minimum_size.y = 46
	box.add_child(discard_amount)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(_button("取消", cancel_discard))
	row.add_child(_button("确认销毁", confirm_discard))
	confirm_shade.hide()
	confirm_panel.hide()

func request_discard() -> void:
	if selected_id == "" or inventory.count(selected_id) <= 0: return
	pending_id = selected_id
	confirm_text.text = "销毁「%s」？\n请选择数量，确认后无法找回。" % inventory.ITEMS[pending_id].name
	discard_amount.max_value = inventory.count(pending_id)
	discard_amount.value = 1
	confirm_shade.show()
	confirm_panel.show()

func cancel_discard() -> void:
	pending_id = ""
	confirm_shade.hide()
	confirm_panel.hide()

func confirm_discard() -> void:
	var id := pending_id
	var amount := int(discard_amount.value)
	cancel_discard()
	if id != "" and inventory.discard(id, amount): set_message("已销毁 %s × %d" % [inventory.ITEMS[id].name, amount])
	else: set_message("物品数量已改变，请重新选择。")
	refresh()

extends Node

signal notified(text: String)
signal tool_changed(tool: String)
signal action_mode_changed(mode: int)
signal equipment_changed
signal quest_changed
signal scene_changing
const SAVE_PATH := "user://meadow_journey.json"
enum ActionMode { INTERACT, LABOR, COMBAT }
const TOOLS := ["axe", "pickaxe", "sickle", "hoe", "fishing_rod"]
const TOOL_NAMES := {"axe": "斧头", "pickaxe": "镐子", "sickle": "镰刀", "hoe":"锄头", "fishing_rod":"鱼竿"}
var inventory = preload("res://scripts/game/Inventory.gd").new()
var tool := "axe"
var tool_stowed := false
var action_mode := ActionMode.INTERACT
var equipment_id := ""
var energy := 100.0
var quest := 0 # 0: unaccepted, 1: collecting, 2: complete
var flags: Dictionary = {}
var health := 100.0
var spawn_side := ""
var changing := false
var world := "village"

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				quest = clampi(int(data.get("quest", 0)), 0, 2)
				action_mode = clampi(int(data.get("action_mode", 0)), 0, 2)
				energy = clampf(float(data.get("energy", 100)), 0, 100)
				equipment_id = str(data.get("equipment_id", ""))
				tool_stowed = bool(data.get("tool_stowed", false))
				health = clampf(float(data.get("health", 100)), 1, 100)
				if data.get("flags") is Dictionary: flags = data.flags
				if data.get("tool") in TOOLS: tool = data.tool
				if data.get("world") in ["village", "wild"]: world = data.world
	inventory.changed.connect(_inventory_changed)
	_validate_equipment()

func save() -> void:
	inventory.save()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"quest": quest, "flags": flags, "tool": tool, "world": world, "health": health, "energy":energy, "action_mode":action_mode, "equipment_id":equipment_id, "tool_stowed":tool_stowed}))

func notify(text: String) -> void:
	notified.emit(text)

func set_action_mode(value: int) -> void:
	action_mode = clampi(value, 0, 2)
	action_mode_changed.emit(action_mode)
	save()

func cycle_tool() -> void:
	var owned: Array = TOOLS.filter(func(id): return inventory.count(id) > 0)
	if owned.is_empty():
		notify("背包里没有可用工具。")
		return
	var index := owned.find(tool)
	tool = owned[(index + 1) % owned.size()]
	tool_stowed = false
	tool_changed.emit(tool)
	notify("已装备：" + TOOL_NAMES[tool])
	save()

func stow_tool() -> void:
	tool_stowed = true
	tool_changed.emit(tool)
	notify("已收起工具，切换或装备工具后可继续劳动。")
	save()

func equip_item(id: String) -> bool:
	if inventory.count(id) <= 0: return false
	if id in TOOLS:
		tool = id
		tool_stowed = false
		tool_changed.emit(tool)
	elif inventory.ITEMS.get(id, {}).get("category", "") == "衣服":
		equipment_id = id
		equipment_changed.emit()
	else: return false
	notify("已装备：" + inventory.ITEMS[id].name)
	save()
	return true

func _validate_equipment() -> void:
	if inventory.count(equipment_id) <= 0:
		equipment_id = ""
		equipment_changed.emit()
	if inventory.count(tool) <= 0:
		var owned: Array = TOOLS.filter(func(id): return inventory.count(id) > 0)
		tool = str(owned[0]) if not owned.is_empty() else ""
		tool_stowed = tool == ""
		tool_changed.emit(tool)

func _inventory_changed() -> void:
	_validate_equipment()
	save()

func update_energy(value: float) -> void:
	energy = value
	save()

func complete_quest() -> bool:
	if quest != 1: return false
	if not inventory.exchange({"wood": 3, "stone": 2, "herb": 2}, {"coin": 50, "potion": 2}):
		notify("还需要：木材3、矿石2、草药2。")
		return false
	quest = 2
	save()
	quest_changed.emit()
	notify("委托完成！获得50金币和2瓶药水。")
	return true

func travel(destination: String) -> void:
	if changing or destination not in ["village", "wild"]: return
	changing = true
	scene_changing.emit()
	var current := get_tree().current_scene
	if current:
		var player := current.get_node_or_null("Player")
		if player: health = maxf(1, player.health)
	world = destination
	spawn_side = "portal"
	save()
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = 100
	add_child(curtain_layer)
	var curtain := ColorRect.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color("152d35")
	curtain.modulate.a = 0
	curtain_layer.add_child(curtain)
	var fade := create_tween()
	fade.tween_property(curtain, "modulate:a", 1.0, 0.2)
	await fade.finished
	var error := get_tree().change_scene_to_file("res://scenes/game/Wild.tscn" if destination == "wild" else "res://scenes/game/Arena.tscn")
	if error != OK:
		changing = false
		curtain_layer.queue_free()
		notify("场景加载失败，请从标题重新进入。")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(curtain, "modulate:a", 0.0, 0.25)
	await fade.finished
	curtain_layer.queue_free()
	changing = false

func update_health(value: float) -> void:
	health = value
	save()

func reset_progress() -> void:
	inventory.stacks = inventory.STARTER.duplicate()
	inventory.slots.clear()
	action_mode = ActionMode.INTERACT
	tool_stowed = false
	equipment_id = ""
	energy = 100
	quest = 0
	flags = {}
	tool = "axe"
	health = 100
	world = "village"
	inventory.changed.emit()
	save()

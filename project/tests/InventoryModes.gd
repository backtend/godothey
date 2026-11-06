extends SceneTree
var failures := 0
var session: Node

func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("INVENTORY/MODES CHECK: " + label)
func select(bag: Control, id: String) -> void:
	bag.select_slot(session.inventory.slots.find(id))

func run_checks() -> void:
	session = preload("res://scripts/game/GameRuntime.gd").ensure_session(self)
	session.reset_progress()
	change_scene_to_file("res://scenes/game/Arena.tscn")
	await create_timer(0.1).timeout
	var player = current_scene.get_node("Player")
	var ui = current_scene.get_node("HUD").get_child(1)
	var controls = ui.controls
	var bag = ui.backpack
	var inventory = session.inventory
	ui.toggle_bag()
	await process_frame
	check(bag.grid.columns == 10 and bag.grid.get_child_count() == 50, "10 columns and 5 rows")
	check(bag.panel.get_global_rect().size.x <= root.get_visible_rect().size.x, "bag fits viewport")
	check(bag.slot_buttons[0].get_node("Count").text == "3", "quantity rendered in icon slot")
	select(bag, "potion")
	check(bag.details.visible and bag.action_button.text == "治疗", "medicine detail shows healing action")
	player.health = 40
	bag.activate_selected()
	check(player.health == 70 and inventory.count("potion") == 2, "medicine heals and consumes once")
	player.health = 100
	bag.activate_selected()
	check(inventory.count("potion") == 2, "full health consumes nothing")
	player.energy = 30
	select(bag, "bread")
	check(bag.action_button.text == "食用", "food action")
	bag.activate_selected()
	check(player.energy == 55 and inventory.count("bread") == 4, "food restores energy and consumes")
	select(bag, "energy_berry")
	bag.activate_selected()
	check(player.energy == 95, "energy item restores energy")
	select(bag, "tunic")
	check(bag.action_button.text == "装备", "clothing action")
	bag.activate_selected()
	check(session.equipment_id == "tunic" and inventory.count("tunic") == 1, "equipment is applied without consuming")
	ui.close_modal()
	player.take_damage(10)
	check(player.health == 93, "equipped clothing reduces damage")
	player.hurt_timer = 0
	ui.toggle_bag()
	select(bag, "hoe")
	bag.activate_selected()
	check(session.tool == "hoe" and not session.tool_stowed, "tool equipped")
	select(bag, "bread")
	bag.request_discard()
	check(bag.confirm_panel.visible and inventory.count("bread") == 4, "discard requires second confirmation")
	bag.cancel_discard()
	check(inventory.count("bread") == 4, "cancel discarding preserves items")
	bag.request_discard()
	bag.discard_amount.value = 2
	bag.confirm_discard()
	check(inventory.count("bread") == 2, "confirmed quantity destroyed")
	select(bag, "tunic")
	bag.request_discard()
	bag.confirm_discard()
	check(session.equipment_id == "", "destroying equipped clothing unequips it")
	bag.sort_bag()
	check(inventory.slots[0] == "axe", "sort groups remaining tools before consumables")
	var saved_slots: Array = inventory.slots.duplicate()
	var reload_inventory = load("res://scripts/game/Inventory.gd").new()
	check(reload_inventory.slots == saved_slots and reload_inventory.count("tunic") == 0, "order persists; discarded equipment does not respawn")
	reload_inventory.load_data({"potion":7, "herb":3, "wood":2, "stone":1, "coin":55})
	check(reload_inventory.count("potion") == 7 and reload_inventory.count("axe") == 1, "legacy flat saves retain amounts and gain starter tools")
	ui.close_modal()
	# Test the actual mode button through touch ownership, not just direct setters.
	for expected in [1, 2, 0]:
		controls._press(5, controls.mode_center)
		controls._release(5)
		check(session.action_mode == expected, "mode button cycles interaction/labor/combat")
	player.position = get_nodes_in_group("villagers")[0].position + Vector2(0, 60)
	await create_timer(0.05).timeout
	controls.trigger_action(0)
	check(ui.mode == "dialogue", "interaction primary talks with NPC")
	var cancel := InputEventScreenTouch.new()
	cancel.index = 4
	cancel.pressed = true
	cancel.position = controls.buttons[2]
	controls._input(cancel)
	check(ui.mode == "" and not player.input_locked, "cancel skill exits dialogue and unlocks input")
	controls.trigger_action(1)
	check(ui.mode == "bag" and is_instance_valid(bag.recipient), "gift skill opens recipient inventory")
	select(bag, "bread")
	check(bag.action_button.text == "赠礼", "gift detail action")
	var npc = bag.recipient
	var before: int = inventory.count("bread")
	bag.activate_selected()
	check(inventory.count("bread") == before - 1 and int(session.flags.get("friendship_" + npc.npc_id, 0)) > 0, "gifting transfers one item and records friendship")
	ui.close_modal()
	session.set_action_mode(1)
	controls.trigger_action(2)
	check(session.tool_stowed, "labor second skill stows tool")
	controls.trigger_action(1)
	check(not session.tool_stowed, "tool cycle draws the next owned tool")
	player.energy = 100
	var soil: Node
	var fishing: Node
	for object in get_nodes_in_group("interactables"):
		if object.get("kind") == "soil": soil = object
		if object.get("kind") == "fishing": fishing = object
	session.equip_item("hoe")
	player.position = soil.position + Vector2(0, 45)
	player.attack_timer = 0
	player.tool_timer = 0
	controls.trigger_action(0)
	check(session.flags.get("tilled_" + soil.object_id, false) and player.energy == 96, "labor primary tills soil with equipped hoe")
	session.equip_item("fishing_rod")
	player.position = fishing.position + Vector2(0, 50)
	player.tool_timer = 0
	controls.trigger_action(0)
	check(inventory.count("fish") == 1, "fishing rod catches fish at fishing point")
	var health_before: float = player.health
	controls.trigger_action(3)
	check(player.health == health_before, "labor empty third skill does nothing")
	session.set_action_mode(2)
	player.tool_timer = 0
	player.attack_timer = 0
	player.cooldowns[0] = 0
	controls.trigger_action(0)
	check(player.state == player.State.ATTACK, "combat primary attacks")
	player.attack_timer = 0
	player.cooldowns[3] = 0
	player.health = 50
	controls.trigger_action(3)
	check(player.health == 70, "combat healing skill unchanged")
	# No stale touches from a mode press or closing a bag may stop the movement finger.
	controls._press(0, controls.activation_region.get_center())
	controls._move(controls.center + Vector2(40, 0))
	controls._press(1, controls.mode_center)
	controls._release(1)
	check(controls.stick_id == 0 and controls.stick_vector.x > 0, "mode switching preserves joystick finger")
	controls._release(0)
	print("INVENTORY AND MODES: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

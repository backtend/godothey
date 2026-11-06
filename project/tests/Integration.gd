extends SceneTree
# Run: Godot --headless --path project --script res://tests/Integration.gd
# Backs up user:// saves and restores them after the checks.
var failures := 0
var session: Node
var backups: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)

func run_checks() -> void:
	session = preload("res://scripts/game/GameRuntime.gd").ensure_session(self)
	for path in [session.SAVE_PATH, session.inventory.SAVE_PATH]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var original_stacks: Dictionary = session.inventory.stacks.duplicate()
	var original_flags: Dictionary = session.flags.duplicate()
	var original_quest: int = session.quest
	var original_world: String = session.world
	var original_health: float = session.health
	var original_tool: String = session.tool
	session.flags = {}
	session.quest = 0
	session.health = 100
	session.changing = false
	session.inventory.stacks = {"potion": 3, "herb": 0, "wood": 0, "stone": 0, "coin": 20}
	change_scene_to_file("res://scenes/game/Arena.tscn")
	await create_timer(0.05).timeout
	var arena := current_scene
	var player = arena.get_node("Player")
	var ui = arena.get_node("HUD").get_child(1)
	check(get_nodes_in_group("villagers").size() == 2, "two NPCs spawn")
	check(arena.get_node("Ground").get_used_cells().size() == 1120, "map dimensions")
	var resource: Node
	for object in get_nodes_in_group("interactables"):
		if object.get("kind") == "tree": resource = object; break
	check(resource != null, "resources spawn")
	resource.use_tool("pickaxe")
	check(session.inventory.stacks.wood == 0, "wrong tool consumes nothing")
	resource.use_tool("axe")
	resource.use_tool("axe")
	check(session.inventory.stacks.wood == 1 and not resource.available, "tool harvest grants one item")
	resource.use_tool("axe")
	check(session.inventory.stacks.wood == 1, "depleted resource cannot be harvested again")
	resource._process(31)
	check(resource.available, "resource regrowth")
	ui.toggle_bag()
	check(player.input_locked and ui.controls.input_locked, "modal locks gameplay")
	player.health = 50
	ui.use_potion()
	check(player.health == 80 and session.inventory.stacks.potion == 2, "potion heals and consumes")
	player.health = 100
	check(not session.inventory.use_item("potion", player), "full health does not consume potion")
	ui.close_modal()
	var ranger: Node
	for npc in get_nodes_in_group("villagers"):
		if npc.npc_id == "ranger": ranger = npc
	ui.nearby = ranger
	ui.start_talk()
	for i in range(3): ui.advance_dialogue()
	check(session.quest == 1, "dialogue starts quest")
	check(session.inventory.stacks.potion == 3, "NPC gives initial gift")
	ui.close_modal()
	ui.nearby = ranger
	ui.start_talk()
	for i in range(3): ui.advance_dialogue()
	check(session.inventory.stacks.potion == 3, "NPC gift not duplicated")
	ui.close_modal()
	check(not session.complete_quest(), "incomplete quest cannot turn in")
	check(not session.inventory.exchange({"coin": 999}, {"potion": 1}), "failed trade is atomic")
	session.inventory.add_item("wood", 2)
	session.inventory.add_item("stone", 2)
	session.inventory.add_item("herb", 2)
	check(session.complete_quest(), "quest completes with materials")
	check(session.quest == 2 and session.inventory.stacks.coin == 70, "quest reward")
	check(not session.complete_quest(), "quest cannot reward twice")
	var chest: Node
	for object in get_nodes_in_group("interactables"):
		if object.get("kind") == "chest": chest = object; break
	chest.interact(player)
	chest.interact(player)
	check(session.inventory.stacks.coin == 85, "chest can only be looted once")
	player.position = Vector2(50, 464)
	player.touch_direction = Vector2.LEFT
	for i in range(30): await physics_frame
	check(player.position.x >= 42, "map collision blocks player")
	player.touch_direction = Vector2.ZERO
	player.attack_timer = 0
	player.use_ability(0)
	check(player.state == player.State.ATTACK, "attack state transition")
	await create_timer(0.5).timeout
	check(player.state == player.State.IDLE, "attack returns to idle")
	# Use the actual activation region so this also covers portrait/headless viewports.
	session.set_action_mode(2)
	var touch_origin: Vector2 = ui.controls.activation_region.get_center()
	ui.controls._press(0, touch_origin)
	ui.controls._move(touch_origin + Vector2(30, 0))
	ui.controls._press(1, ui.controls.buttons[0])
	ui.controls._release(1)
	check(ui.controls.stick_id == 0, "second finger release preserves joystick")
	ui.controls._release(0)
	check(ui.controls.stick_vector == Vector2.ZERO, "joystick release resets direction")

	session.travel("wild")
	await create_timer(0.7).timeout
	check(current_scene.biome == "wild", "portal changes scene")
	check(session.inventory.stacks.coin == 85 and session.quest == 2, "scene travel preserves inventory and quest")
	check(get_nodes_in_group("villagers").is_empty(), "village NPCs absent from wilderness")
	var slimes: Array = []
	for enemy in get_nodes_in_group("training_dummy"):
		if enemy is CharacterBody2D: slimes.append(enemy)
	check(slimes.size() == 3, "wild enemies spawn")
	var slime = slimes[0]
	slime.take_hit(3)
	await process_frame
	check(not is_instance_valid(slime), "enemy defeat removes enemy")
	check(session.inventory.stacks.coin == 90, "enemy reward")
	player = current_scene.get_node("Player")
	player.take_damage(10)
	check(player.health == 90, "enemy damage")
	player.hurt_timer = 0
	player.take_damage(999)
	await create_timer(0.7).timeout
	check(current_scene.biome == "village" and current_scene.get_node("Player").health == 100, "death returns player to village")
	var reloaded = load("res://scripts/game/Inventory.gd").new()
	check(reloaded.stacks.coin == 90, "inventory persists to disk")
	for object in get_nodes_in_group("interactables"):
		if object.get("kind") == "chest": check(not object.available, "chest remains opened after travel")
	session.inventory.stacks = original_stacks
	session.flags = original_flags
	session.quest = original_quest
	session.world = original_world
	session.health = original_health
	session.tool = original_tool
	for path in backups:
		if backups[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
	print("MEADOW INTEGRATION: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

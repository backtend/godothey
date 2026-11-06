extends SceneTree
var output := OS.get_environment("UI_CAPTURE_DIR")
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var session = preload("res://scripts/game/GameRuntime.gd").ensure_session(self)
	session.reset_progress()
	change_scene_to_file("res://scenes/game/Arena.tscn")
	await create_timer(0.3).timeout
	var ui = current_scene.get_node("HUD").get_child(1)
	var player = current_scene.get_node("Player")
	for mode in range(3):
		session.set_action_mode(mode)
		await shot(["interaction", "labor", "combat"][mode])
	ui.toggle_bag()
	await process_frame
	var bag = ui.backpack
	var potion: Button = bag.slot_buttons[session.inventory.slots.find("potion")]
	await click(potion.get_global_rect().get_center())
	if bag.selected_id != "potion":
		push_error("Real mouse selection failed")
		quit(1)
		return
	await shot("bag")
	player.health = 50
	await click(bag.action_button.get_global_rect().get_center())
	if player.health != 80:
		push_error("Real mouse healing failed")
		quit(1)
		return
	await click(bag.discard_button.get_global_rect().get_center())
	await shot("discard_confirmation")
	bag.cancel_discard()
	await click(bag.slot_buttons[session.inventory.slots.find("tunic")].get_global_rect().get_center())
	await shot("clothing")
	bag.close_bag()
	session.set_action_mode(0)
	player.position = get_nodes_in_group("villagers")[0].position + Vector2(0, 55)
	await create_timer(0.05).timeout
	ui.open_gift()
	bag.select_slot(session.inventory.slots.find("bread"))
	await shot("gift")
	print("INVENTORY UI CAPTURE: PASS")
	quit()

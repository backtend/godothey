extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
func run_check() -> void:
	if not ProjectSettings.load_resource_pack("/tmp/godothey_build_check/godothey-smoke.pck", true):
		push_error("Unable to mount exported PCK")
		quit(1)
		return
	change_scene_to_file("res://scenes/home/Home.tscn")
	await create_timer(0.2).timeout
	if not current_scene.has_node("Player") or not root.has_node("GameSession"):
		push_error("Exported gameplay failed to initialize")
		quit(1)
		return
	print("EXPORTED PCK GAMEPLAY: PASS")
	quit()

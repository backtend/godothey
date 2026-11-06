extends SceneTree

# Run against the loopback fixture server in an isolated test profile.
var failures := 0
var fixture_dir := "user://packaging/files/"
var fixture_root := OS.get_environment("RELEASE_FIXTURE_DIR")
const VERSION := "99.101.1"
const CODE := 9901010001

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("RELEASE CHECK FAILED: " + description)

func wait_scene(path: String) -> bool:
	for i in range(300):
		if current_scene and current_scene.scene_file_path == path: return true
		await create_timer(0.05).timeout
	return false

func build_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	var source := "user://probe.txt"
	var f := FileAccess.open(source, FileAccess.WRITE)
	f.store_string("mounted-after-cold-start")
	f.close()
	var script_source := "user://session_patch.gd"
	f = FileAccess.open(script_source, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://scripts/game/GameSession.gd") + "\nfunc patch_marker() -> String:\n\treturn \"patched-session\"\n")
	f.close()
	var packer := PCKPacker.new()
	check(packer.pck_start(fixture_root + "/fixture.pck") == OK, "start fixture PCK")
	check(packer.add_file("res://tests/cold_start_probe.txt", source) == OK, "pack marker")
	check(packer.add_file("res://scripts/game/GameSession.gd", script_source) == OK, "pack session script")
	check(packer.flush() == OK, "flush fixture PCK")
	f = FileAccess.open(fixture_root + "/fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"tag":"release-test", "pck_name":"fixture.pck", "pck_mode":"all_resources", "pck_vname":VERSION, "pck_vcode":CODE, "pck_size":FileAccess.get_file_as_bytes(fixture_root + "/fixture.pck").size(), "pck_hash":FileAccess.get_sha256(fixture_root + "/fixture.pck"), "pck_url":OS.get_environment("HTTP_BASE_URL") + "/fixture.pck"}))
	f.close()

func mount_again() -> void:
	var boot: Node = load("res://scenes/Bootstrap.tscn").instantiate()
	boot.set_script(load("res://tests/MountHarness.gd"))
	root.add_child(boot)
	await process_frame
	await boot._apply_local_pcks()
	check(FileAccess.get_file_as_string("res://tests/cold_start_probe.txt") == "mounted-after-cold-start", "PCK mounts even when last_pck_vcode already equals version")
	check(int(root.get_node("Configuration").getUserValue("APP", "last_pck_vcode", 0)) == CODE, "effective patch version")
	boot.queue_free()
	await process_frame

func run_checks() -> void:
	HttpMdtLib.BASE_URL = OS.get_environment("HTTPX_MDT_URL")
	if OS.get_cmdline_user_args().has("cold"):
		await mount_again()
		change_scene_to_file("res://scenes/auth/Login.tscn")
		await create_timer(0.1).timeout
		current_scene.guest_button.pressed.emit()
		await create_timer(0.15).timeout
		check(root.has_node("GameSession"), "guest initializes gameplay after mounting")
		if root.has_node("GameSession"):
			check(root.get_node("GameSession").call("patch_marker") == "patched-session", "new process uses patched session script")
		print("RELEASE COLD START: ", "PASS" if failures == 0 else "FAIL")
		quit(0 if failures == 0 else 1)
		return
	build_fixture()
	check(not root.has_node("GameSession"), "gameplay not loaded as an Autoload")
	ProjectSettings.set_setting("application/config/version", "test.optional")
	change_scene_to_file("res://scenes/Bootstrap.tscn")
	check(await wait_scene("res://scenes/checking/Update.tscn"), "Bootstrap to resource update")
	await create_timer(0.15).timeout
	check(current_scene._update_mode == 3, "optional resource update")
	current_scene.cancel_button.pressed.emit()
	check(await wait_scene("res://scenes/auth/Login.tscn"), "cancel update returns to login")
	check(not root.has_node("GameSession"), "login does not preload gameplay")
	current_scene.guest_button.pressed.emit()
	check(await wait_scene("res://scenes/home/Home.tscn"), "guest enters Home")
	await create_timer(0.1).timeout
	check(current_scene.has_node("Player"), "guest sees playable world")
	# Remove gameplay so patched code must be loaded fresh later in the same test.
	var session := root.get_node("GameSession")
	session.queue_free()
	ProjectSettings.set_setting("application/config/version", "test.apk")
	change_scene_to_file("res://scenes/Bootstrap.tscn")
	check(await wait_scene("res://scenes/checking/Upgrade.tscn"), "Bootstrap to APK upgrade")
	await create_timer(0.15).timeout
	check(current_scene._upgrade_mode == 1 and not current_scene.cancel_button.visible, "mandatory APK upgrade cannot be skipped")
	ProjectSettings.set_setting("application/config/version", "test.optional")
	change_scene_to_file("res://scenes/checking/Update.tscn")
	await create_timer(0.2).timeout
	var update := current_scene
	check(await update._run_update(update._packages), "download, hash, mount and record PCK")
	check(FileAccess.file_exists(fixture_dir + VERSION + ".pck"), "complete PCK committed")
	check(not FileAccess.file_exists(fixture_dir + VERSION + ".pck.part"), "temporary download removed")
	check(update._load_manifest().applied.size() == 1, "manifest records one package")
	check(await update._run_update(update._packages), "repeated update is idempotent")
	check(update._load_manifest().applied.size() == 1, "manifest does not duplicate package")
	var broken := FileAccess.open(fixture_dir + VERSION + ".pck", FileAccess.WRITE)
	broken.store_string("interrupted download")
	broken.close()
	check(await update._run_update(update._packages), "corrupt applied file downloads again")
	check(FileAccess.get_sha256(fixture_dir + VERSION + ".pck") == str(update._packages[0].pck_hash), "redownload repairs hash")
	root.get_node("Configuration").setUserValue("APP", "last_pck_vcode", CODE)
	await mount_again()
	ProjectSettings.set_setting("application/config/version", "test.offline")
	change_scene_to_file("res://scenes/Bootstrap.tscn")
	check(await wait_scene("res://scenes/auth/Login.tscn"), "failed initial check still presents login/guest choice")
	print("RELEASE FLOW: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

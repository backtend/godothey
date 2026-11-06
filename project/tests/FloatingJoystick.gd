extends SceneTree

class SessionStub extends Node:
	var action_mode := 2
	var changing := false
	var world := "village"
	const TOOL_NAMES := {"axe": "斧头"}
	var tool := "axe"

class PlayerStub extends CharacterBody2D:
	var touch_direction := Vector2.ZERO
	var cooldowns := [0.0, 0.0, 0.0, 0.0]
	var health := 100.0
	var attacks := 0
	func use_ability(_index: int) -> void: attacks += 1

var failures := 0
func _initialize() -> void:
	call_deferred("check_controls")
func expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func check_controls() -> void:
	var session := SessionStub.new()
	session.name = "GameSession"
	root.add_child(session)
	var player := PlayerStub.new()
	root.add_child(player)
	var controls = load("res://scripts/game/MobileControls.gd").new()
	controls.player = player
	root.add_child(controls)
	var home: Vector2 = controls.home_center
	var point: Vector2 = controls.activation_region.position + controls.activation_region.size * Vector2(0.8, 0.6)
	controls._press(0, point)
	expect(controls.center == point and controls.stick_vector == Vector2.ZERO, "touch becomes center without moving character")
	controls._move(point + Vector2(28.5, 0))
	expect(controls.center == point, "drag keeps the new origin")
	expect(controls.stick_vector.x > 0.4 and controls.stick_vector.x < 0.5, "relative half-speed analog movement")
	controls.queue_redraw()
	await process_frame
	expect(controls.center == point, "drawing does not reset floating center")
	controls._move(point + Vector2(300, 300))
	expect(is_equal_approx(controls.stick_vector.length(), 1), "long diagonal drag clamps to full speed")
	controls._press(1, controls.buttons[0])
	controls._release(1)
	expect(controls.stick_id == 0 and controls.center == point, "attack finger leaves joystick untouched")
	expect(player.attacks == 1, "simultaneous attack works")
	controls._release(0)
	expect(controls.center == home and player.touch_direction == Vector2.ZERO, "release resets both visual and movement immediately")
	controls._press(2, Vector2(root.size.x * 0.7, root.size.y * 0.65))
	expect(controls.stick_id == -1, "outside region does not activate joystick")
	controls._press(3, point)
	controls._move(point + Vector2(controls.STICK_TRAVEL * (controls.stick_deadzone + 0.001), 0))
	expect(controls.stick_vector.length() < 0.002, "deadzone exit is continuous")
	controls._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(controls.stick_id == -1 and controls.center == home, "focus loss resets joystick")
	controls._press(4, point)
	controls._update_layout()
	expect(controls.stick_id == -1 and player.touch_direction == Vector2.ZERO, "resize cancels active touch")
	print("FLOATING JOYSTICK: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

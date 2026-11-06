extends Control

signal action_requested(index: int)
signal cancel_requested

enum Mode { INTERACT, LABOR, COMBAT }
const MODE_NAMES := ["交互", "劳动", "战斗"]
const ACTION_NAMES := [["交互 [E]", "赠礼 [G]", "取消 / 离开", ""], ["使用工具 [F]", "切换工具 [Tab]", "收起工具", ""], ["攻击 [J]", "冲刺 [K]", "震波 [L]", "治疗 [H]"]]
const ACTION_ICONS := [["interact", "gift", "cancel", ""], ["tool", "cycle", "stow", ""], ["attack", "dash", "shockwave", "heal"]]
var icon_cache: Dictionary = {}
var mode_center := Vector2.ZERO
var ui_context: Control
var session: Node

@export_range(0.0, 0.3) var stick_deadzone := 0.06
const STICK_TRAVEL := 57.0
var activation_region := Rect2()
var home_center := Vector2.ZERO
var input_locked := false
var player: CharacterBody2D
var stick_id := -1
var stick_vector := Vector2.ZERO
var active_buttons: Dictionary = {}
var center := Vector2.ZERO
var buttons: Array[Vector2] = []

func _ready() -> void:
	session = get_node("/root/GameSession")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	for name in ["interact", "gift", "cancel", "cycle", "stow", "attack", "dash", "shockwave", "heal"]:
		icon_cache[name] = load("res://assets/ui/icons/" + name + ".svg")

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player.touch_direction = stick_vector
	queue_redraw()

func _draw() -> void:
	draw_circle(center, 85, Color(0.1, 0.18, 0.23, 0.65))
	draw_arc(center, 85, 0, TAU, 64, Color(0.6, 0.85, 0.9, 0.8), 3)
	draw_circle(center + stick_vector * STICK_TRAVEL, 29, Color(0.55, 0.85, 0.92, 0.9))
	var font: Font = load(ProjectSettings.get_setting("gui/theme/custom_font"))
	for i in range(buttons.size()):
		_draw_action(i, font)
	var tint := _mode_color()
	draw_circle(mode_center, 34, Color("182e41"))
	draw_arc(mode_center, 35, 0, TAU, 64, tint, 2.5)
	draw_texture_rect(icon_cache["cycle"], Rect2(mode_center - Vector2(18, 21), Vector2(36, 36)), false)
	_centered(font, mode_center + Vector2(0, 24), MODE_NAMES[session.action_mode], 16, Color("f2dfa8"))

	if is_instance_valid(player):
		draw_style_box(_hud_box(), Rect2(12, 10, 370, 175))
		draw_string(font, Vector2(24, 36), ("青禾村" if session.world == "village" else "薄雾林地") + "  /  MEADOW JOURNEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_rect(Rect2(24, 52, 220, 16), Color(0.15, 0.2, 0.2))
		draw_rect(Rect2(24, 52, 220 * player.health / 100.0, 16), Color(0.3, 0.85, 0.5))
		if player.get("energy") != null:
			draw_rect(Rect2(24, 102, 220, 5), Color("243b49"))
			draw_rect(Rect2(24, 102, 220 * player.energy / 100.0, 5), Color("73adca"))
		draw_string(font, Vector2(24, 94), "生命 %d / 100  ·  %s" % [player.health, session.TOOL_NAMES.get(session.tool, "空手")], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _mode_color() -> Color:
	return [Color("83cdd1"), Color("a6cc86"), Color("e0bd76")][session.action_mode]

func _centered(font: Font, point: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, point - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_action(index: int, font: Font) -> void:
	var point := buttons[index]
	var big := index == 0
	var radius := 63.0 if big else 45.0
	var empty: bool = ACTION_NAMES[session.action_mode][index] == ""
	var tint := _mode_color() if not empty else Color("3e5665")
	draw_circle(point + Vector2(0, 4), radius + 4, Color(0.02, 0.05, 0.08, 0.65))
	draw_circle(point, radius + 3, Color("152331"))
	draw_circle(point, radius, Color("496478"))
	draw_circle(point - Vector2(0, 1), radius - 4, Color("1d354b"))
	draw_circle(point - Vector2(0, 5), radius - 9, Color("294d60") if not empty else Color("1d303e"))
	draw_arc(point, radius, 0, TAU, 72, tint, 2.5)
	draw_arc(point, radius - 5, PI * 1.1, PI * 1.8, 32, Color(0.9, 0.95, 1, 0.35), 1.5)
	if empty: return
	var name: String = ACTION_ICONS[session.action_mode][index]
	var texture: Texture2D
	if name == "tool":
		texture = preload("res://scripts/game/SproutArt.gd").icon(session.tool) if session.tool != "" else icon_cache["stow"]
	else: texture = icon_cache[name]
	var icon_size := 56.0 if big else 42.0
	draw_texture_rect(texture, Rect2(point - Vector2(icon_size * 0.5, icon_size * 0.5 + 8), Vector2.ONE * icon_size), false)
	var cooldown := float(player.cooldowns[index]) if session.action_mode == Mode.COMBAT and is_instance_valid(player) else 0.0
	if cooldown > 0:
		draw_circle(point, radius - 4, Color(0.03, 0.08, 0.13, 0.7))
		draw_arc(point, radius - 5, -PI * 0.5, -PI * 0.5 + TAU * minf(1, cooldown / [0.4, 3.0, 5.0, 8.0][index]), 64, tint, 4)
		_centered(font, point + Vector2(0, 5), "%.1f" % cooldown, 24, Color.WHITE)
	_centered(font, point + Vector2(0, 31 if big else 29), ACTION_NAMES[session.action_mode][index], 15 if big else 12, Color("f0e4c9"))

func trigger_action(index: int) -> void:
	if input_locked or session.changing or index < 0 or index > 3: return
	if ACTION_NAMES[session.action_mode][index] == "": return
	if session.action_mode == Mode.COMBAT:
		if is_instance_valid(player): player.use_ability(index)
	else: action_requested.emit(index)

func _input(event: InputEvent) -> void:
	if session.changing: return
	if input_locked:
		# The interaction-mode cancel skill can close dialogue, even while movement is locked.
		if session.action_mode == Mode.INTERACT and is_instance_valid(ui_context) and ui_context.mode == "dialogue":
			if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed and event.position.distance_to(buttons[2]) < 48:
				cancel_requested.emit()
				get_viewport().set_input_as_handled()
		return
	# Touch-to-mouse emulation must not create a second joystick/button press.
	if event is InputEventMouse and event.device == -1: return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag and event.index == stick_id:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(-2, event.position)
		else:
			_release(-2)
	elif event is InputEventMouseMotion and stick_id == -2:
		_move(event.position)

func _press(id: int, point: Vector2) -> void:
	if input_locked or session.changing: return
	if id == stick_id or active_buttons.has(id): return
	if point.distance_to(mode_center) < 37:
		active_buttons[id] = 4
		session.set_action_mode((session.action_mode + 1) % 3)
		queue_redraw()
		return
	if stick_id == -1 and activation_region.has_point(point):
		stick_id = id
		center = point
		_set_vector(Vector2.ZERO)
		queue_redraw()
		return
	for i in range(buttons.size()):
		if point.distance_to(buttons[i]) < (66 if i == 0 else 48):
			active_buttons[id] = i
			trigger_action(i)
			return

func _move(point: Vector2) -> void:
	if stick_id == -1: return
	var offset := (point - center) / STICK_TRAVEL
	var strength := minf(offset.length(), 1.0)
	# Remap the deadzone continuously: crossing it never jumps to 15% speed.
	var amount := maxf(0.0, (strength - stick_deadzone) / (1.0 - stick_deadzone))
	_set_vector(offset.normalized() * amount)
	queue_redraw()

func _set_vector(value: Vector2) -> void:
	stick_vector = value
	if is_instance_valid(player): player.touch_direction = value

func reset_stick() -> void:
	stick_id = -1
	center = home_center
	_set_vector(Vector2.ZERO)
	active_buttons.clear()
	queue_redraw()

func _release(id: int) -> void:
	if id == stick_id:
		stick_id = -1
		center = home_center
		_set_vector(Vector2.ZERO)
		queue_redraw()
	active_buttons.erase(id)

func _update_layout() -> void:
	var viewport := get_viewport_rect().size
	home_center = Vector2(145, viewport.y - 145)
	# Keep the center-bottom interaction/tool buttons outside the joystick region.
	var width := maxf(0, minf(viewport.x * 0.38, viewport.x * 0.5 - 220))
	activation_region = Rect2(Vector2(0, viewport.y * 0.55), Vector2(width, viewport.y * 0.45))
	buttons = [Vector2(viewport.x - 110, viewport.y - 120), Vector2(viewport.x - 245, viewport.y - 100), Vector2(viewport.x - 215, viewport.y - 230), Vector2(viewport.x - 90, viewport.y - 265)]
	mode_center = buttons[3] - Vector2(0, 102)
	reset_stick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_stick()

func _hud_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.16, 0.8)
	style.set_corner_radius_all(10)
	return style

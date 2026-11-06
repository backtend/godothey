extends Control

var session: Node

func _ready() -> void:
	await get_tree().process_frame
	session = preload("res://scripts/game/GameRuntime.gd").ensure_session(get_tree())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color("152d35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 22)
	box.add_theme_font_override("font", load(ProjectSettings.get_setting("gui/theme/custom_font")))
	box.add_theme_font_size_override("font_size", 23)
	center.add_child(box)
	var logo := TextureRect.new()
	logo.texture = preload("res://scripts/game/SproutArt.gd").object("house")
	logo.custom_minimum_size = Vector2(100, 100)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(logo)
	for text in ["青 禾 物 语", "MEADOW JOURNEY  /  采集 · 探索 · 生活"]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	var play := Button.new()
	play.text = "出发 / 继续旅程"
	play.custom_minimum_size.y = 64
	play.pressed.connect(_begin)
	box.add_child(play)
	var fresh := Button.new()
	fresh.text = "开始新的旅程"
	fresh.custom_minimum_size.y = 50
	box.add_child(fresh)
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "新的旅程"
	confirmation.dialog_text = "重新开始会覆盖当前冒险的背包和任务进度。"
	confirmation.ok_button_text = "重新开始"
	confirmation.cancel_button_text = "保留存档"
	confirmation.confirmed.connect(func():
		session.reset_progress()
		_begin()
	)
	add_child(confirmation)
	fresh.pressed.connect(func(): confirmation.popup_centered(Vector2i(480, 180)))
	var hint := Label.new()
	hint.text = "WASD 移动 · E 交互 · F 使用工具 · Q 切换工具\n手机支持多点触控 · 进度自动保存\n先找巡林员阿远，开启你的第一份委托。\n部分美术：Sprout Lands — Cup Nooble"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)
	session.changing = false

func _begin() -> void:
	if session.changing: return
	session.travel(session.world)
	session.spawn_side = ""

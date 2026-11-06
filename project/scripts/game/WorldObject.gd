extends StaticBody2D

var session: Node

signal harvested(item: String, amount: int)
var kind := "tree"
var object_id := ""
var destination := "wild"
var display_name := ""
var available := true
var regrow := 0.0
var hits := 0
var sprite: Sprite2D
var label: Label
const NAMES := {"tree": "松树 · 需要斧头", "rock": "矿石 · 需要镐子", "herb": "草药 · 需要镰刀", "chest": "宝箱", "portal": "路口", "camp": "营火 · 休息", "dummy": "练习假人", "soil":"田地", "fishing":"钓鱼点"}
const REQUIRED := {"tree": "axe", "rock": "pickaxe", "herb": "sickle", "soil":"hoe", "fishing":"fishing_rod"}
const DROPS := {"tree": "wood", "rock": "stone", "herb": "herb", "fishing":"fish"}

func _ready() -> void:
	session = get_node("/root/GameSession")
	add_to_group("interactables")
	if kind == "dummy": add_to_group("training_dummy")
	display_name = NAMES.get(kind, kind) if display_name == "" else display_name
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15 if kind != "tree" else 20
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	var art := kind
	sprite.texture = preload("res://scripts/game/SproutArt.gd").object(art)
	sprite.scale = Vector2(2.5, 2.5) if kind == "tree" else Vector2(2, 2)
	sprite.position.y = -22
	if kind == "fishing":
		sprite.scale = Vector2(0.65, 0.65)
		sprite.position.y = -12
	add_child(sprite)
	if kind in ["soil", "fishing"]: collision_layer = 0
	label = Label.new()
	label.text = display_name
	label.add_theme_font_override("font", load(ProjectSettings.get_setting("gui/theme/custom_font")))
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(-100, -88 if kind == "tree" else -70)
	label.size.x = 200
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	if kind == "soil" and session.flags.get("tilled_" + object_id, false):
		sprite.modulate = Color(0.7, 0.55, 0.4)
		label.text = "已翻好的田地"
	if kind == "chest" and session.flags.get(object_id, false):
		available = false
		label.text = "已打开的宝箱"
		sprite.texture = preload("res://scripts/game/SproutArt.gd").object("chest", true)
		sprite.modulate = Color(0.6, 0.6, 0.6)

func _process(delta: float) -> void:
	var player := get_parent().get_node_or_null("Player")
	if player and kind in REQUIRED:
		label.visible = player.global_position.distance_to(global_position) < 145
	if regrow > 0:
		regrow -= delta
		if regrow <= 0:
			if player and player.global_position.distance_to(global_position) < 40:
				regrow = 1
				return
			collision_layer = 0 if kind in ["soil", "fishing"] else 1
			available = true
			hits = 0
			sprite.modulate = Color.WHITE
			label.text = display_name

func interact(player: CharacterBody2D) -> void:
	if kind in REQUIRED:
		session.notify("装备" + session.TOOL_NAMES[REQUIRED[kind]] + "，按工具 [F] 采集。")
	elif kind == "portal":
		session.travel(destination)
	elif kind == "camp":
		player.health = 100
		player.energy = 100
		session.health = 100
		session.save()
		session.notify("在营火旁休息，生命与体力已恢复。进度已保存。")
	elif kind == "chest":
		if not available:
			session.notify("宝箱已经被打开了。")
			return
		if not session.inventory.exchange({}, {"coin": 15, "potion": 1}):
			session.notify("背包物品已达上限。")
			return
		available = false
		session.flags[object_id] = true
		session.save()
		label.text = "已打开的宝箱"
		sprite.texture = preload("res://scripts/game/SproutArt.gd").object("chest", true)
		sprite.modulate = Color(0.6, 0.6, 0.6)
		session.notify("打开宝箱：获得15金币、1瓶药水！")
	elif kind == "dummy":
		session.notify("朝向假人按 J 攻击，或 L 释放震波。")

func use_tool(tool: String) -> bool:
	if not kind in REQUIRED: return false
	if not available:
		session.notify("资源正在恢复，稍后再来。")
		return false
	if tool != REQUIRED[kind]:
		session.notify("工具不合适，需要" + session.TOOL_NAMES[REQUIRED[kind]])
		return false
	if kind == "soil":
		if session.flags.get("tilled_" + object_id, false):
			session.notify("这块田地已经翻好土了。")
			return false
		session.flags["tilled_" + object_id] = true
		session.save()
		sprite.modulate = Color(0.7, 0.55, 0.4)
		label.text = "已翻好的田地"
		session.notify("翻土完成！")
		return true
	hits += 1
	var tween := create_tween()
	sprite.modulate = Color(2, 2, 2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if hits < (2 if kind in ["tree", "rock"] else 1):
		session.notify("再使用一次工具即可采集。")
		return true
	var item: String = DROPS[kind]
	if not session.inventory.add_item(item, 1):
		session.notify("背包已满或物品已达上限。")
		return false
	available = false
	collision_layer = 0
	regrow = 5 if kind == "fishing" else 30
	harvested.emit(item, 1)
	session.notify("获得" + session.inventory.ITEMS[item].name + " × 1")
	label.text = "鱼群暂时散开了" if kind == "fishing" else "恢复中"
	tween.kill()
	sprite.modulate = Color(0.4, 0.45, 0.4, 0.45)
	return true

func take_hit(_damage: int) -> void:
	var tween := create_tween()
	sprite.modulate = Color(2, 2, 2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

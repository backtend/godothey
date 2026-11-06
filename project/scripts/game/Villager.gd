extends StaticBody2D

var session: Node

var npc_id := "healer"
var display_name := ""
var npc_name := "旅人"
var lines: Array[String] = []
var gift := "herb"
var gifted := false
var tint := Color.WHITE

func _ready() -> void:
	session = get_node("/root/GameSession")
	add_to_group("villagers")
	add_to_group("interactables")
	display_name = npc_name
	gifted = session.flags.get("gift_" + npc_id, false)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://scripts/game/SproutArt.gd").region("characters/basic_character_spritesheet.png", Rect2(0, 0, 48, 48))
	sprite.position.y = -14
	sprite.scale = Vector2(2, 2)
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var label := Label.new()
	label.text = npc_name + " · 交谈"
	label.add_theme_font_override("font", load(ProjectSettings.get_setting("gui/theme/custom_font")))
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(-65, -68)
	label.size.x = 130
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func receive_gift(id: String) -> bool:
	var item: Dictionary = session.inventory.ITEMS.get(id, {})
	if not item.get("gift", false): return false
	if not session.inventory.exchange({id:1}, {}): return false
	var key := "friendship_" + npc_id
	var points := 8 if id == "herb" and npc_id == "healer" else 5
	session.flags[key] = int(session.flags.get(key, 0)) + points
	session.save()
	session.notify("%s收下了%s，好感 +%d" % [npc_name, item.name, points])
	return true

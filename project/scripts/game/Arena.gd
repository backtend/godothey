extends Node2D

var session: Node

@export_enum("village", "wild") var biome := "village"

const MAP_SIZE := Vector2i(40, 28)
const CELL := 32

func _ready() -> void:
	await get_tree().process_frame
	session = preload("res://scripts/game/GameRuntime.gd").ensure_session(get_tree())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(CELL, CELL)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	for i in range(5):
		var source := TileSetAtlasSource.new()
		var tile_image := preload("res://scripts/game/SproutArt.gd").tile(i)
		source.texture = ImageTexture.create_from_image(tile_image)
		source.texture_region_size = Vector2i(CELL, CELL)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source, i)
		if i == 2:
			var data := source.get_tile_data(Vector2i.ZERO, 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tiles
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ground)
	var obstacles := TileMapLayer.new()
	obstacles.name = "Obstacles"
	obstacles.tile_set = tiles
	obstacles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(obstacles)
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var grass_id: int = [0, 3, 4][posmod(x * 17 + y * 31, 3)]
			ground.set_cell(cell, 1 if abs(y - 14) <= 1 or abs(x - 20) <= 1 else grass_id, Vector2i.ZERO)
			if x == 0 or y == 0 or x == MAP_SIZE.x - 1 or y == MAP_SIZE.y - 1 or (x >= 7 and x <= 11 and y >= 6 and y <= 10):
				obstacles.set_cell(cell, 2, Vector2i.ZERO)
	var player := preload("res://scenes/entities/player/Player.tscn").instantiate()
	player.position = Vector2(656, 464)
	add_child(player)
	player.health_changed.connect(session.update_health)
	player.energy_changed.connect(session.update_energy)
	session.world = biome
	if session.spawn_side == "portal":
		player.position = Vector2(1100, 464) if biome == "village" else Vector2(176, 464)
	session.spawn_side = ""
	if biome == "wild":
		ground.modulate = Color(0.77, 0.9, 0.85)
	_spawn_object("portal", Vector2(112, 464) if biome == "wild" else Vector2(1168, 464), "exit", "返回青禾村" if biome == "wild" else "前往薄雾林地")
	_spawn_object("camp", Vector2(600, 345), "camp")
	_spawn_object("chest", Vector2(1000, 250), biome + "_chest")
	_spawn_object("soil", Vector2(352, 624), biome + "_soil", "田地 · 需要锄头")
	_spawn_object("fishing", Vector2(416, 336), biome + "_fishing", "池塘钓鱼点 · 需要鱼竿")
	_spawn_object("dummy", Vector2(800, 464), "dummy")
	var used: Array[Vector2] = [Vector2(352, 624), Vector2(416, 336), player.position, Vector2(600, 345), Vector2(1000, 250), Vector2(800, 464), Vector2(112, 464), Vector2(1168, 464)]
	var npc_positions: Array[Vector2] = []
	for i in range(2):
		var npc := preload("res://scripts/game/Villager.gd").new()
		npc.position = Vector2(470 + i * 370, 360 + randi_range(-35, 35))
		npc_positions.append(npc.position)
		used.append(npc.position)
		npc.npc_id = "healer" if i == 0 else "ranger"
		npc.npc_name = "药师小禾" if i == 0 else "巡林员阿远"
		npc.tint = Color(0.6, 1, 0.7) if i == 0 else Color(0.7, 0.8, 1)
		if i == 0:
			npc.lines.assign(["欢迎来到青禾村。我是药师小禾。", "用镰刀采集草药，带两株回来，我可以帮你调制生命药水。", "初次见面，送你一株草药。右上背包可以使用药水或更换工具。"])
			npc.gift = "herb"
		else:
			npc.lines.assign(["我是巡林员阿远。村子需要一批修缮物资。", "请带回木材3份、矿石2份、草药2份。斧头砍树，镐子挖矿，镰刀采药。", "东边路口通往薄雾林地，小心史莱姆！带齐材料再来找我领取报酬。"])
			npc.gift = "potion"
		if biome == "village": add_child(npc)
		else: npc.free()
	if biome == "wild":
		used.append_array([Vector2(900, 620), Vector2(1050, 700), Vector2(850, 200)])
	var candidates: Array[Vector2] = []
	for y in range(4, 24):
		for x in range(3, 37):
			var cell := Vector2i(x, y)
			var point := Vector2(cell * CELL) + Vector2(16, 16)
			if obstacles.get_cell_source_id(cell) != -1 or abs(y - 14) <= 2 or abs(x - 20) <= 1: continue
			var clear := true
			for occupied in used:
				if point.distance_to(occupied) < 110: clear = false
			if clear: candidates.append(point)
	candidates.shuffle()
	for i in range(24 if biome == "wild" else 12):
		if candidates.is_empty(): break
		var point: Vector2 = candidates.pop_back()
		_spawn_object(["tree", "rock", "herb"][i % 3], point, "%s_resource_%d" % [biome, i])
		var remaining: Array[Vector2] = []
		for candidate in candidates:
			if candidate.distance_to(point) > 80: remaining.append(candidate)
		candidates = remaining
	if biome == "wild":
		for point in [Vector2(900, 620), Vector2(1050, 700), Vector2(850, 200)]:
			var slime := preload("res://scripts/game/Slime.gd").new()
			slime.position = point
			slime.player = player
			add_child(slime)
	else:
		for point in [Vector2(480, 190), Vector2(720, 190)]:
			var house := Sprite2D.new()
			house.texture = preload("res://scripts/game/SproutArt.gd").object("house")
			house.scale = Vector2(2, 2)
			house.position = point
			add_child(house)
			var body := StaticBody2D.new()
			body.position = point + Vector2(0, 28)
			var collision := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(96, 60)
			collision.shape = rectangle
			body.add_child(collision)
			add_child(body)
	if biome == "village":
		for i in range(3):
			var animal := preload("res://scripts/game/FarmAnimal.gd").new()
			animal.kind = "cow" if i == 2 else "chicken"
			animal.position = Vector2(440 + i * 100, 600)
			add_child(animal)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var controls := preload("res://scripts/game/MobileControls.gd").new()
	controls.player = player
	hud.add_child(controls)
	var adventure := preload("res://scripts/game/AdventureUI.gd").new()
	adventure.player = player
	adventure.controls = controls
	hud.add_child(adventure)
	session.save()

func _spawn_object(kind: String, point: Vector2, id: String, title := "") -> void:
	var object := preload("res://scripts/game/WorldObject.gd").new()
	object.kind = kind
	object.position = point
	object.object_id = id
	object.display_name = title
	object.destination = "village" if biome == "wild" else "wild"
	add_child(object)


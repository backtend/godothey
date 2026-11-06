extends RefCounted
# Original sheets stay intact. AtlasTexture regions are native Godot resources.
const ROOT := "res://assets/sprout_lands/"
static func region(file: String, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(ROOT + file)
	texture.region = rect
	return texture

static func object(kind: String, opened := false) -> Texture2D:
	match kind:
		"soil": return region("tilesets/tilled_dirt_v2.png", Rect2(16, 16, 16, 16))
		"fishing": return icon("fishing_rod")
		"tree": return region("objects/basic_grass_biome_things.png", Rect2(16, 0, 32, 32))
		"rock": return region("objects/basic_grass_biome_things.png", Rect2(128, 16, 16, 16))
		"herb": return region("objects/basic_plants.png", Rect2(32, 0, 16, 16))
		"chest": return region("objects/chest.png", Rect2(96 if opened else 0, 0, 48, 48))
		"house": return region("objects/free_chicken_house.png", Rect2(0, 0, 48, 48))
	return load("res://assets/handmade/" + kind + ".svg")

static func icon(kind: String) -> Texture2D:
	if kind in ["bread", "energy_berry", "fish", "tunic", "hoe", "fishing_rod"]:
		return load("res://assets/ui/icons/" + kind + ".svg")
	match kind:
		"stone": return region("objects/basic_tools_and_materials.png", Rect2(0, 16, 16, 16))
		"wood": return region("objects/basic_tools_and_materials.png", Rect2(32, 16, 16, 16))
		"axe": return region("objects/basic_tools_and_materials.png", Rect2(32, 0, 16, 16))
		"pickaxe": return region("objects/basic_tools_and_materials.png", Rect2(16, 0, 16, 16))
		"herb": return object("herb")
	return load("res://assets/handmade/" + kind + ".svg")

static func tile(index: int) -> Image:
	var file := "tilesets/grass.png"
	var rect := Rect2i(16, 16, 16, 16)
	if index == 1:
		file = "tilesets/tilled_dirt_v2.png"
		rect = Rect2i(16, 16, 16, 16)
	elif index == 2:
		file = "tilesets/water.png"
		rect = Rect2i(0, 0, 16, 16)
	var texture: Texture2D = load(ROOT + file)
	var image := texture.get_image().get_region(rect)
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	if index in [3, 4]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 24 + index
		for i in range(4):
			var point := Vector2i(rng.randi_range(3, 28), rng.randi_range(3, 28))
			image.fill_rect(Rect2i(point, Vector2i(2, 2)), Color("bfdc80") if index == 3 else Color("e3e9a1"))
	return image

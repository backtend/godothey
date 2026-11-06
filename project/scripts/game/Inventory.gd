extends RefCounted

signal changed
const SAVE_PATH := "user://arena_inventory.json"
const CAPACITY := 50
const ITEMS := {
	"potion": {"name":"生命药水", "description":"药师调制的恢复药剂，使用后恢复30点生命。生命已满时不会消耗。", "category":"药品", "action":"治疗", "health":30, "order":20, "rarity":1, "gift":true},
	"bread": {"name":"香麦面包", "description":"刚烤好的麦香面包。恢复8点生命与25点体力，适合劳动后补充能量。", "category":"食品", "action":"食用", "health":8, "energy":25, "order":30, "rarity":0, "gift":true},
	"energy_berry": {"name":"活力浆果", "description":"带着晨露的蓝色浆果，食用后恢复40点体力。", "category":"能量", "action":"食用", "energy":40, "order":31, "rarity":1, "gift":true},
	"fish": {"name":"溪流鲜鱼", "description":"从清澈溪流中钓到的鲜鱼，恢复5点生命与15点体力。也可以送给村民。", "category":"食品", "action":"食用", "health":5, "energy":15, "order":32, "rarity":0, "gift":true},
	"tunic": {"name":"青禾旅衣", "description":"耐磨的绿色旅行衣。装备后每次受到的伤害减少3点，衣服不会因装备而消耗。", "category":"衣服", "action":"装备", "defense":3, "order":0, "rarity":1, "gift":true},
	"axe": {"name":"伐木斧", "description":"用于砍伐树木。劳动模式按F使用，两次挥砍可获得木材。", "category":"工具", "action":"装备", "order":10, "rarity":0, "gift":false},
	"pickaxe": {"name":"采矿镐", "description":"用于开采矿石。劳动模式靠近矿石按F使用。", "category":"工具", "action":"装备", "order":11, "rarity":0, "gift":false},
	"sickle": {"name":"采药镰刀", "description":"用于收割草药。劳动模式靠近草药按F使用。", "category":"工具", "action":"装备", "order":12, "rarity":0, "gift":false},
	"hoe": {"name":"农耕锄", "description":"用于整理田地。劳动模式靠近村庄的田地按F翻土。", "category":"工具", "action":"装备", "order":13, "rarity":0, "gift":false},
	"fishing_rod": {"name":"竹制鱼竿", "description":"用于钓鱼。劳动模式靠近池塘钓鱼点按F钓取鲜鱼，鱼群约5秒恢复。", "category":"工具", "action":"装备", "order":14, "rarity":1, "gift":false},
	"herb": {"name":"草药", "description":"带有清香的炼药材料。药师小禾可将两株草药调制成一瓶药水。", "category":"材料", "order":40, "rarity":0, "gift":true},
	"wood": {"name":"木材", "description":"砍树获得的木材，可用于村庄修缮委托，也可赠送给村民。", "category":"材料", "order":41, "rarity":0, "gift":true},
	"stone": {"name":"矿石", "description":"开采获得的矿石，可用于修缮委托与锻造。", "category":"材料", "order":42, "rarity":0, "gift":true},
	"coin": {"name":"金币", "description":"村庄商店的通用货币。巡林员阿远以10枚金币出售一瓶生命药水。", "category":"货币", "order":50, "rarity":1, "gift":false}
}
const STARTER := {"potion":3, "bread":5, "energy_berry":3, "tunic":1, "axe":1, "pickaxe":1, "sickle":1, "hoe":1, "fishing_rod":1, "fish":0, "herb":0, "wood":0, "stone":0, "coin":20}
var stacks: Dictionary = STARTER.duplicate()
var slots: Array[String] = []

func _init() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file: load_data(JSON.parse_string(file.get_as_text()))
	_sync_slots()

func load_data(data: Variant) -> void:
	if not data is Dictionary: return
	var modern: bool = data.get("version", 0) == 2 and data.get("stacks") is Dictionary
	var amounts: Dictionary = data.stacks if modern else data
	# Old flat saves gain starter tools once; modern saves never resurrect discarded items.
	stacks = {} if modern else STARTER.duplicate()
	for id in ITEMS:
		if amounts.get(id) is float or amounts.get(id) is int:
			stacks[id] = clampi(int(amounts[id]), 0, 999)
	slots.clear()
	if modern and data.get("slots") is Array:
		for id in data.slots:
			if id is String and ITEMS.has(id) and not slots.has(id) and count(id) > 0 and slots.size() < CAPACITY:
				slots.append(id)
	_sync_slots()

func count(id: String) -> int:
	return int(stacks.get(id, 0))

func _sync_slots() -> void:
	var next: Array[String] = []
	for id in slots:
		next.append(id if count(id) > 0 and ITEMS.has(id) and not next.has(id) else "")
	next.resize(CAPACITY)
	for i in range(CAPACITY):
		if next[i] == null: next[i] = ""
	for id in ITEMS:
		if count(id) > 0 and not next.has(id):
			var free := next.find("")
			if free >= 0: next[free] = id
	slots = next

func save() -> void:
	_sync_slots()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version":2, "stacks":stacks, "slots":slots}))

func add_item(id: String, amount: int) -> bool:
	if not ITEMS.has(id): return false
	return exchange({id:-amount}, {}) if amount < 0 else exchange({}, {id:amount})

func exchange(cost: Dictionary, reward: Dictionary) -> bool:
	var next := stacks.duplicate()
	for id in cost:
		if not ITEMS.has(id) or int(cost[id]) < 0 or count(id) < int(cost[id]): return false
		next[id] = count(id) - int(cost[id])
	for id in reward:
		if not ITEMS.has(id) or int(reward[id]) < 0: return false
		next[id] = int(next.get(id, 0)) + int(reward[id])
		if int(next[id]) > 999: return false
	var used := 0
	for id in next:
		if int(next[id]) > 0: used += 1
	if used > CAPACITY: return false
	stacks = next
	save()
	changed.emit()
	return true

func discard(id: String, amount: int) -> bool:
	return amount > 0 and exchange({id:amount}, {})

func sort_items() -> void:
	var occupied: Array[String] = []
	for id in ITEMS:
		if count(id) > 0: occupied.append(id)
	occupied.sort_custom(func(a, b):
		if ITEMS[a].order != ITEMS[b].order: return ITEMS[a].order < ITEMS[b].order
		return str(ITEMS[a].name).naturalnocasecmp_to(str(ITEMS[b].name)) < 0
	)
	slots = occupied
	save()
	changed.emit()

func use_item(id: String, player: CharacterBody2D) -> bool:
	if not ITEMS.has(id) or count(id) <= 0: return false
	var item: Dictionary = ITEMS[id]
	if item.get("action", "") not in ["食用", "治疗"]: return false
	var heal := float(item.get("health", 0))
	var energy := float(item.get("energy", 0))
	if not ((heal > 0 and player.health < 100) or (energy > 0 and player.energy < 100)): return false
	# Commit consumption before emitting health/energy signals that save the session.
	if not exchange({id:1}, {}): return false
	player.health = minf(100, player.health + heal)
	if energy > 0: player.energy = minf(100, player.energy + energy)
	return true

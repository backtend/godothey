extends CharacterBody2D

var session: Node

signal state_changed(previous: int, current: int)
signal health_changed(value: float)
signal energy_changed(value: float)
const TOOL_ART := {"axe": preload("res://assets/handmade/axe.svg"), "pickaxe": preload("res://assets/handmade/pickaxe.svg"), "sickle": preload("res://assets/handmade/sickle.svg")}
var energy := 100.0:
	set(value):
		energy = clampf(value, 0, 100)
		energy_changed.emit(energy)

enum State { IDLE, MOVE, ATTACK, DASH, TOOL, HURT, UI }
@export var speed := 180.0
var state := State.IDLE
var input_locked := false
var touch_direction := Vector2.ZERO
var playerDirection := Vector2.DOWN
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var health := 100.0:
	set(value):
		health = clampf(value, 0, 100)
		health_changed.emit(health)
var hit_count := 0
var attack_timer := 0.0
var dash_timer := 0.0
var tool_timer := 0.0
var hurt_timer := 0.0
var effect_timer := 0.0
var effect_radius := 70.0
var effect_color := Color.WHITE
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	session = get_node("/root/GameSession")
	health = session.health
	energy = session.energy
	session.equipment_changed.connect(apply_equipment)
	sprite.position = Vector2(0, -14)
	sprite.scale = Vector2(2, 2)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	apply_equipment()
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11
	collision.shape = circle
	add_child(collision)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1280
	camera.limit_bottom = 896
	add_child(camera)
	_fit_camera(camera)
	get_viewport().size_changed.connect(_fit_camera.bind(camera))

func transition(next: State) -> void:
	if state == next: return
	var previous := state
	state = next
	state_changed.emit(previous, state)

func _physics_process(delta: float) -> void:
	for i in range(cooldowns.size()): cooldowns[i] = maxf(0, cooldowns[i] - delta)
	attack_timer = maxf(0, attack_timer - delta)
	dash_timer = maxf(0, dash_timer - delta)
	tool_timer = maxf(0, tool_timer - delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	effect_timer = maxf(0, effect_timer - delta)
	var direction := Input.get_vector("left", "right", "up", "down")
	if touch_direction != Vector2.ZERO: direction = touch_direction.limit_length()
	if input_locked or session.changing:
		direction = Vector2.ZERO
		dash_timer = 0
		transition(State.UI)
	elif hurt_timer > 0:
		transition(State.HURT)
	elif attack_timer > 0:
		transition(State.ATTACK)
	elif tool_timer > 0:
		transition(State.TOOL)
	elif dash_timer > 0:
		transition(State.DASH)
	else:
		transition(State.MOVE if direction != Vector2.ZERO else State.IDLE)
		if direction != Vector2.ZERO: playerDirection = direction.normalized()
		if session.action_mode == 2 and Input.is_action_just_pressed("attack"): use_ability(0)
	velocity = Vector2.ZERO
	match state:
		State.MOVE: velocity = direction * speed
		State.DASH: velocity = playerDirection * speed * 3.5
		State.HURT: velocity = -playerDirection * 55
	move_and_slide()
	if state not in [State.ATTACK, State.TOOL]:
		animationPlayer.play(("walk_" if velocity != Vector2.ZERO else "idle_") + get_animation_direction())
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if input_locked or session.changing: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_K:
				if session.action_mode == 2: use_ability(1)
			KEY_L:
				if session.action_mode == 2: use_ability(2)
			KEY_H:
				if session.action_mode == 2: use_ability(3)
			KEY_F:
				if session.action_mode == 1: use_tool()
			KEY_Q:
				if session.action_mode == 1: session.cycle_tool()

func use_tool() -> void:
	if input_locked or session.changing or attack_timer > 0 or tool_timer > 0 or dash_timer > 0 or hurt_timer > 0: return
	if session.tool_stowed or session.tool == "" or session.inventory.count(session.tool) <= 0:
		session.notify("请先装备工具，或按 Tab 切换工具。")
		return
	if energy < 4:
		session.notify("体力不足，在背包食用食物或到营火休息。")
		return
	tool_timer = 0.4
	transition(State.TOOL)
	animationPlayer.play("attack_" + get_animation_direction())
	_show_effect(85, Color(0.6, 0.9, 0.7))
	var nearest: Node2D
	var distance := 100.0
	for object in get_tree().get_nodes_in_group("interactables"):
		if not object.has_method("use_tool"): continue
		if object.kind not in ["tree", "rock", "herb", "soil", "fishing"]: continue
		var candidate: float = global_position.distance_to(object.global_position)
		if candidate < distance:
			distance = candidate
			nearest = object
	if nearest:
		playerDirection = global_position.direction_to(nearest.global_position)
		if nearest.use_tool(session.tool): energy -= 4
	else:
		session.notify("靠近树木、矿石或草药后使用工具。")

func use_ability(index: int) -> void:
	if input_locked or session.changing or cooldowns[index] > 0 or hurt_timer > 0: return
	if attack_timer > 0 or tool_timer > 0 or dash_timer > 0: return
	match index:
		0:
			cooldowns[0] = 0.4
			attack_timer = 0.35
			transition(State.ATTACK)
			animationPlayer.play("attack_" + get_animation_direction())
			_show_effect(80, Color(1, 0.8, 0.3))
			_hit_targets(80, true)
		1:
			cooldowns[1] = 3.0
			dash_timer = 0.18
			transition(State.DASH)
			_show_effect(35, Color(0.4, 0.8, 1))
		2:
			cooldowns[2] = 5.0
			attack_timer = 0.3
			transition(State.ATTACK)
			animationPlayer.play("attack_" + get_animation_direction())
			_show_effect(150, Color(0.5, 0.5, 1))
			_hit_targets(150, false)
		3:
			if health >= 100: return
			cooldowns[3] = 8.0
			health += 20
			_show_effect(55, Color(0.3, 1, 0.5))

func take_damage(amount: float) -> void:
	if input_locked or hurt_timer > 0 or dash_timer > 0: return
	var defense := float(session.inventory.ITEMS.get(session.equipment_id, {}).get("defense", 0))
	health -= maxf(1, amount - defense)
	hurt_timer = 0.45
	transition(State.HURT)
	_show_effect(40, Color(1, 0.4, 0.4))
	if health <= 0:
		health = 100
		session.health = 100
		session.notify("你被营地救援队带回村庄，背包物品保留。")
		input_locked = true
		session.travel("village")

func _hit_targets(radius: float, directional: bool) -> void:
	for target in get_tree().get_nodes_in_group("training_dummy"):
		var offset: Vector2 = target.global_position - global_position
		if offset.length() <= radius and (not directional or offset.normalized().dot(playerDirection) >= 0.3):
			hit_count += 1
			if target.has_method("take_hit"): target.take_hit(1 if directional else 2)

func _show_effect(radius: float, color: Color) -> void:
	effect_timer = 0.3
	effect_radius = radius
	effect_color = color

func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 16, Color(0.08, 0.14, 0.13, 0.35))
	draw_set_transform(Vector2.ZERO)
	if state == State.TOOL:
		draw_set_transform(Vector2(18 * signf(playerDirection.x) if playerDirection.x != 0 else 16, -10), sin(tool_timer * 14) * 0.8, Vector2(1.5, 1.5))
		draw_texture_rect(preload("res://scripts/game/SproutArt.gd").icon(session.tool), Rect2(-16, -16, 32, 32), false)
		draw_set_transform(Vector2.ZERO)
	if effect_timer > 0:
		var color := effect_color
		color.a = effect_timer / 0.3
		draw_arc(Vector2.ZERO, effect_radius * (1 - effect_timer), 0, TAU, 64, color, 4)

func get_animation_direction() -> String:
	if abs(playerDirection.x) > abs(playerDirection.y):
		sprite.flip_h = playerDirection.x < 0
		return "side"
	return "up" if playerDirection.y < 0 else "down"

func _fit_camera(camera: Camera2D) -> void:
	var viewport := get_viewport_rect().size
	var scale_factor := maxf(1.0, maxf(viewport.x / 1280.0, viewport.y / 896.0))
	camera.zoom = Vector2.ONE * scale_factor

func apply_equipment() -> void:
	if is_instance_valid(sprite):
		sprite.modulate = Color(0.7, 1, 0.8) if session.equipment_id != "" else Color.WHITE

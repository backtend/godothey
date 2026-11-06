extends CharacterBody2D

var session: Node

signal defeated
# The enemy has an explicit IDLE -> CHASE -> ATTACK / HURT -> DEAD state machine.
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state := State.IDLE
var hp := 3
var timer := 0.0
var home := Vector2.ZERO
var player: CharacterBody2D
var sprite: Sprite2D

func _ready() -> void:
	session = get_node("/root/GameSession")
	add_to_group("training_dummy")
	home = position
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/handmade/slime.svg")
	sprite.scale = Vector2(2, 2)
	sprite.position.y = -16
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or state == State.DEAD: return
	timer = maxf(0, timer - delta)
	velocity = Vector2.ZERO
	var distance := global_position.distance_to(player.global_position)
	if state == State.HURT:
		if timer <= 0: state = State.IDLE
	elif state == State.ATTACK:
		if timer <= 0: state = State.IDLE
	elif player.input_locked or session.changing:
		state = State.IDLE
	elif distance < 42:
		state = State.ATTACK
		timer = 1.0
		player.take_damage(10)
	elif distance < 230 and position.distance_to(home) < 300:
		state = State.CHASE
		velocity = global_position.direction_to(player.global_position) * 65
	else:
		state = State.IDLE
		if position.distance_to(home) > 12: velocity = position.direction_to(home) * 40
	move_and_slide()
	sprite.position.y = -16 + sin(Time.get_ticks_msec() * 0.007) * 3
	queue_redraw()

func take_hit(damage: int) -> void:
	if state in [State.DEAD, State.HURT]: return
	hp -= damage
	state = State.HURT
	timer = 0.3
	sprite.modulate = Color(2, 0.7, 0.7)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		state = State.DEAD
		session.inventory.add_item("coin", 5)
		session.notify("击败史莱姆，获得5金币。")
		defeated.emit()
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-22, -53, 44, 5), Color(0.2, 0.25, 0.3))
	draw_rect(Rect2(-22, -53, 44 * maxf(hp, 0) / 3.0, 5), Color(0.8, 0.5, 0.5))

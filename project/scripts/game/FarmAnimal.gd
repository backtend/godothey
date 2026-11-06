extends CharacterBody2D

var session: Node
var kind := "chicken"
var home := Vector2.ZERO
var direction := Vector2.ZERO
var timer := 0.0
var display_name := "小鸡 · 打招呼"
var sprite: AnimatedSprite2D

func _ready() -> void:
	session = get_node("/root/GameSession")
	home = position
	add_to_group("interactables")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10 if kind == "chicken" else 18
	collision.shape = circle
	add_child(collision)
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5)
	var sheet := "characters/free_chicken_sprites.png" if kind == "chicken" else "characters/free_cow_sprites.png"
	var cell := Vector2(16, 16) if kind == "chicken" else Vector2(32, 32)
	for i in range(4 if kind == "chicken" else 3):
		frames.add_frame("walk", preload("res://scripts/game/SproutArt.gd").region(sheet, Rect2(Vector2(i * cell.x, 0), cell)))
	sprite.sprite_frames = frames
	sprite.scale = Vector2(2, 2)
	sprite.position.y = -10 if kind == "chicken" else -20
	add_child(sprite)
	if kind != "chicken": display_name = "奶牛 · 打招呼"

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		timer = randf_range(1.5, 3.0)
		direction = Vector2.from_angle(randf() * TAU) if randf() > 0.4 else Vector2.ZERO
	if position.distance_to(home) > 100: direction = position.direction_to(home)
	var player := get_parent().get_node_or_null("Player")
	velocity = direction * 22
	if player and player.input_locked: velocity = Vector2.ZERO
	move_and_slide()
	if velocity != Vector2.ZERO:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
	else:
		sprite.stop()

func interact(_player: CharacterBody2D) -> void:
	session.notify("咯咯！小鸡歪着头看着你。" if kind == "chicken" else "哞——奶牛悠闲地打了个招呼。")

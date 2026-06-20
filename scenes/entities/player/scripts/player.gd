extends CharacterBody2D

# 玩家移动速度（像素/秒）
@export var speed: float = 100.0

# 当前输入得到的移动方向向量
var moveDirection: Vector2 = Vector2.ZERO
var playerDirection: Vector2 = Vector2.DOWN

# 动画播放器引用
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer

# 玩家精灵引用（用于左右翻转）
@onready var sprite: Sprite2D = $Sprite2D

# 每帧物理更新：读取输入 -> 计算速度 -> 移动 -> 切换动画
func _physics_process(delta: float) -> void:
	var xAxios: float = Input.get_axis("left", "right")
	var yAxios: float = Input.get_axis("up", "down")
	moveDirection = Vector2(xAxios, yAxios)
	
	# 角色移动
	velocity = moveDirection * speed
	move_and_slide()

	_update_direction_and_animation()



func _update_direction_and_animation() -> void:

	# 根据输入方向播放对应行走动画
	if moveDirection != Vector2.ZERO:
		var newDirection: Vector2
		if abs(moveDirection.x) > abs(moveDirection.y):
			newDirection = Vector2.RIGHT if moveDirection.x > 0 else Vector2.LEFT
		else:
			newDirection = Vector2.DOWN if moveDirection.y > 0 else Vector2.UP

		if newDirection != playerDirection:
			playerDirection = newDirection


	#if moveDirection != Vector2.ZERO:
	#	if xAxios > 0:
	#		animationPlayer.play("walk_side")
	#		sprite.flip_h = false
	#	elif xAxios < 0:
	#		animationPlayer.play("walk_side")
	#		sprite.flip_h = true
	#	elif yAxios > 0:
	#		animationPlayer.play("walk_down")
	#	elif yAxios < 0:
	#		animationPlayer.play("walk_up")
	#		
	#else:
	#	# 无输入时默认待机朝下
	#	animationPlayer.play("idle_down")


	#更新动画
	update_animation()

# 更新角色的动画
func update_animation() -> void:
	var currentState = "walk" if moveDirection != Vector2.ZERO else "idle"
	var direction: String = get_animation_direction()
	var animationName:String = currentState + "_" + direction

	if animationPlayer.has_animation(animationName):
		animationPlayer.play(animationName)
	else:
		print_debug("动画不存在啊啊：" + animationName)

# 获取动画方向的字符串
func get_animation_direction() -> String:
	if abs(playerDirection.x) > abs(playerDirection.y):
		sprite.flip_h = playerDirection.x < 0
		return "side"
	if playerDirection.y < 0:
		return "up"
	return "down"

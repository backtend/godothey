extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    # 每秒钟打印一次delta时间
    if delta > 999:
        print("Delta time: ", delta)
    # print("Delta time: ", delta)


    var moveY: float = Input.get_action_strength("down") - Input.get_action_strength("up")
    # print(    "Y轴的值是-value: " , moveY)
    position.y += moveY

    var moveX: float = Input.get_action_strength("right") - Input.get_action_strength("left")
    # print(    "X轴的值是-value: " , moveX)
    position.x += moveX

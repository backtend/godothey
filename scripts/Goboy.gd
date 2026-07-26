extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    var moveY: float = Input.get_action_strength("down") - Input.get_action_strength("up")
    # print(    "Y轴的值是-value: " , moveY)
    position.y += moveY

    var moveX: float = Input.get_action_strength("right") - Input.get_action_strength("left")
    # print(    "X轴的值是-value: " , moveX)
    position.x += moveX

extends CharacterBody2D

@export var speed: float = 100.0

var move_direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var x_axios: float = Input.get_axis("left", "right")
	var y_axios: float = Input.get_axis("up", "down")
	move_direction = Vector2(x_axios, y_axios)
	
	velocity = move_direction * speed
	move_and_slide()

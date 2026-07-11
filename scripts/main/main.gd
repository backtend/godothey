extends Node

func _ready() -> void:
	Auth.check_login_success.connect(_go_main)
	Auth.check_login_failed.connect(_go_login)
	if Auth.has_token():
		Auth.check_login()
	else:
		_go_login()

func _go_main() -> void:
	print("Token is valid. Redirecting to main scene.")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")

func _go_login() -> void:
	print("No valid token found or token check failed. Redirecting to login scene.")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

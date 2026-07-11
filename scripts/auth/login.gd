extends Control

@onready var username_edit: LineEdit = $VBoxContainer/UsernameEdit
@onready var password_edit: LineEdit = $VBoxContainer/PasswordEdit
@onready var error_label: Label = $VBoxContainer/ErrorLabel
@onready var login_button: Button = $VBoxContainer/LoginButton

func _ready() -> void:
	error_label.text = ""
	login_button.pressed.connect(_on_login_pressed)
	Auth.login_success.connect(_on_login_success)
	Auth.login_failed.connect(_on_login_failed)

func _on_login_pressed() -> void:
	var u := username_edit.text.strip_edges()
	var p := password_edit.text
	print("正在登录")
	if u.is_empty() or p.is_empty():
		error_label.text = "please input username and password"
		#return
		
	login_button.disabled = true
	error_label.text = "登录中..."
	Auth.login(u, p)

func _on_login_success() -> void:
	print("ready goto main sence...")
	#get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")

func _on_login_failed(msg: String) -> void:
	login_button.disabled = false
	error_label.text = msg

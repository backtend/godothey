extends Control

@onready var username_edit: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/UsernameEdit
@onready var password_edit: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PasswordEdit
@onready var error_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ErrorLabel
@onready var login_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LoginButton
@onready var guest_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GuestButton


func _ready() -> void:
    error_label.text = ""

    login_button.pressed.connect(_on_login_pressed)
    guest_button.pressed.connect(_on_guest_pressed)

    Auth.login_success.connect(_on_login_success)
    Auth.login_failed.connect(_on_login_failed)


func _on_login_pressed() -> void:
    var u := username_edit.text.strip_edges()
    var p := password_edit.text

    if u.is_empty() or p.is_empty():
        error_label.text = "Please enter username and password."
        return

    login_button.disabled = true
    error_label.text = "Signing in..."

    Auth.login(u, p)


func _on_guest_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/home/Home.tscn")


func _on_login_success() -> void:
    get_tree().call_deferred(
        "change_scene_to_file",
		"res://scenes/home/Home.tscn"
    )


func _on_login_failed(msg: String) -> void:
    login_button.disabled = false
    error_label.text = msg

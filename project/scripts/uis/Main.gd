extends Node


@onready var version_label: Label = $CanvasLayer/Panel/VersionLabel

func _ready() -> void:
    print("Main.gd _ready() called.")
    print("Client UUID:", Configuration.get_val("clientuuid"))


    var version_name = ProjectSettings.get_setting("application/config/version", "")
    if version_label:
        version_label.text = "Version: %s" % version_name

        
    await get_tree().create_timer(1.0).timeout
    
    var toscene := await WelcomeLogic.initial()
    print("初始化完成，跳转到：", toscene)
    get_tree().call_deferred("change_scene_to_file", toscene)

    
# func _after_upgrade_check() -> void:
#     Auth.check_login_success.connect(_go_main)
#     Auth.check_login_failed.connect(_go_login)
#     if Auth.has_token():
#         Auth.check_login()
#     else:
#         _go_login()

# func _go_main() -> void:
#     print("Token is valid. Redirecting to main scene.")
#     get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")

# func _go_login() -> void:
#     print("No valid token found or token check failed. Redirecting to login scene.")
#     get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

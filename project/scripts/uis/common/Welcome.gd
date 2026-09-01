extends Node


@onready var version_label: Label = $CanvasLayer/Panel/VersionLabel

func _ready() -> void:
    print("Main.gd _ready() called.")
    print("Client UUID:", Configuration.getUserValue("APP", "client_uuid"))

    # 上次运行时间记录-当前手机时间的 年月日时分秒
    var last_run_time: String = Configuration.getUserValue("APP", "last_run_time", "")
    Configuration.setUserValue("APP", "last_run_time", Time.get_datetime_string_from_system())
    print("Last run time:", last_run_time)

    var appVersionName = ProjectSettings.get_setting("application/config/version", "")
    var appVersionCode = ProjectSettings.get_setting("application/config/version_code", "")
    var build = ProjectSettings.get_setting("application/config/build", "")
    if version_label:
        version_label.text = "App-%s " % [appVersionName]
        version_label.text += "Res-%s " % [Configuration.getResValue("PACKAGE", "build_pck_vname", "0.0.0")]
    
    print("APP UUID==:", Configuration.getUserValue("APP", "client_uuid"))
    print("APP Version Name=", appVersionName)
    print("APP Version Code=", appVersionCode)
    print("APP Version Build=", build)
    print("PCK getResValue build_pck_vname:", Configuration.getResValue("PACKAGE", "build_pck_vname"))
    print("PCK getResValue build_pck_vcode:", Configuration.getResValue("PACKAGE", "build_pck_vcode"))

    await get_tree().create_timer(EnvedLib.editor(1.0, 7.0)).timeout
    
    var toscene := await WelcomeLogic.initial()
    print("初始化完成，跳转到：", toscene)
    get_tree().call_deferred("change_scene_to_file", toscene)

    
# func _after_upgrade_check() -> void:
#     Authy.check_login_success.connect(_go_main)
#     Authy.check_login_failed.connect(_go_login)
#     if Authy.has_token():
#         Authy.check_login()
#     else:
#         _go_login()

# func _go_main() -> void:
#     print("Token is valid. Redirecting to main scene.")
#     get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")

# func _go_login() -> void:
#     print("No valid token found or token check failed. Redirecting to login scene.")
#     get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

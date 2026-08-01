extends Node

@onready var version_label: Label = $CanvasLayer/Panel/VersionLabel

func _ready() -> void:
    print("Main.gd _ready() called.")
    print("Client UUID:", Configuration.get_val("clientuuid"))
    await get_tree().create_timer(2.0).timeout
    await _check_upgrade()

    # 更新版本号标签
    var version_name = ProjectSettings.get_setting("application/config/version", "")
    if version_label:
        version_label.text = "Version: %s" % version_name


func _get_upgrade_url() -> String:
    var base_url := "https://apix.yongit.com/programer/check"
    var version_name: String = ProjectSettings.get_setting("application/config/version", "")
    var params := {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": version_name,
        "gray_target": Configuration.get_val("clientuuid")
    }
    var query_parts := PackedStringArray()
    for key in params:
        query_parts.append("%s=%s" % [key.uri_encode(), str(params[key]).uri_encode()])
    return "%s?%s" % [base_url, "&".join(query_parts)]

func _check_upgrade() -> void:
    # 当前版本号
    var version_name = ProjectSettings.get_setting("application/config/version")
    print("Project Version:", version_name, " Client UUID:", Configuration.get_val("clientuuid"))

    var http := HTTPRequest.new()
    add_child(http)

    var err := http.request(_get_upgrade_url())
    if err != OK:
        push_warning("升级检查请求发起失败: %s" % err)
        http.queue_free()
        _after_upgrade_check()
        return

    var result: Array = await http.request_completed
    http.queue_free()

    var http_result: int = result[0]
    var response_code: int = result[1]
    var body: PackedByteArray = result[3]

    if http_result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        push_warning("升级检查网络错误，HTTP状态: %s" % response_code)
        _after_upgrade_check()
        return

    var json := JSON.new()
    var parse_err := json.parse(body.get_string_from_utf8())
    if parse_err != OK:
        push_warning("升级检查JSON解析失败: %s" % json.get_error_message())
        _after_upgrade_check()
        return

    var res: Dictionary = json.get_data()
    if res.get("code", -1) != 200:
        push_warning("升级检查业务错误: %s" % res.get("msg", ""))
        _after_upgrade_check()
        return

    # 写个日志
    print("Upgrade check response: %s" % res)
    var data: Dictionary = res.get("data", {})
    Updater.set_from_data(data)


    match Updater.upgrade_mode:
        1, 3:
            # 强制升级 / 提示升级 -> 进入升级场景
            get_tree().call_deferred("change_scene_to_file", "res://scenes/upgrade/Upgrade.tscn")
        _:
            # 2（忽略）或其他未知值 -> 走正常登录流程
            _after_upgrade_check()

    # _after_upgrade_check()


func _after_upgrade_check() -> void:
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

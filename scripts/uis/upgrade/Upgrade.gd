extends Control

@onready var title_label: Label = %TitleLabel
@onready var intro_label: Label = %IntroLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var _upgrade_mode: int = 0
var _release_url: String = ""

func _ready() -> void:
    var res: Array = await HttpMdtLib.doPost("/upgrade/check", {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": ProjectSettings.get_setting("application/config/version", ""),
        "client_uuid": str(Configuration.get_val("clientuuid")),
        "gray_target": "x123123"
    })
    var _code: int = res[0]; var _msg: String = res[1]; var _data: Dictionary = res[2]
    print("升级检查JSON解析: %s %s %s" % [_code, _msg, _data])

    if _code != 200:
        push_warning(_msg)
        print("升级检查请求发起失败，即将前往首页: %s" % _msg)
        get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")
        return

    var package: Dictionary = _data.get("package", {}) # 资源包升级
    var program: Dictionary = _data.get("program", {}) # 程序升级


    match int(program.get("upgrade_mode", 0)):
        1, 3:
            # 强制升级 / 提示升级 -> 把检查结果挂到 root，交给 Upgrade 场景读取
            pass
        4:
            # 强制升级 / 提示升级 -> 把检查结果挂到 root，交给 Upgrade 场景读取
            pass
        _:
            get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

    _upgrade_mode = int(program.get("upgrade_mode", 0))
    if _upgrade_mode == 2:
        print("无需升级，直接跳转到登录界面")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")
        return

    _release_url = _data.get("release_url", "")

    title_label.text = _data.get("title", "")
    intro_label.text = "[%s]%s" % [ProjectSettings.get_setting("application/config/version", ""), _data.get("intro", "")]
    status_label.text = ""

    cancel_button.visible = (_upgrade_mode != 1)
    if _upgrade_mode == 1:
        get_tree().root.set_meta("_block_back", true)

    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)


func _on_cancel_pressed() -> void:
    get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

func _on_confirm_pressed() -> void:
    if UpgradeLogic.open_release_url(_release_url):
        status_label.text = "已跳转到浏览器，请下载并安装新版本"
    else:
        status_label.text = "打开下载地址失败，请检查网络或稍后重试"
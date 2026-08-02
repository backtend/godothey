extends Control

@onready var title_label: Label = %TitleLabel
@onready var intro_label: Label = %IntroLabel
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var _upgrade_mode: int = 0
var _release_url: String = ""

func _ready() -> void:
    var result := await UpgradeLogic.check_upgrade(self)
    if not result.success:
        push_warning(result.error)
        _after_upgrade_check()
        return

    var data: Dictionary = result.data
    print("Upgrade check response data: %s" % data)

    match int(data.get("upgrade_mode", 0)):
        1, 3:
            # 强制升级 / 提示升级 -> 把检查结果挂到 root，交给 Upgrade 场景读取
            get_tree().call_deferred("change_scene_to_file", "res://scenes/upgrade/Upgrade.tscn")
        _:
            _after_upgrade_check()


    var data: Dictionary = get_tree().root.get_meta("upgrade_info", {})
    get_tree().root.remove_meta("upgrade_info")

    _upgrade_mode = int(data.get("upgrade_mode", 0))
    _release_url = data.get("release_url", "")

    title_label.text = data.get("title", "")
    intro_label.text = "[%s]%s" % [version_name, data.get("intro", "")]
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
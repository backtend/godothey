extends Control
## Bootstrap 场景 —— 项目的真正入口场景。
## 在 Project Settings -> Application -> Run -> Main Scene 中把它设为 Bootstrap.tscn。
##
## 重要:这个场景本身【永远不会】被你的增量热更新覆盖,它是整套热更新机制的
## "引导层"——引擎在它自己的 _ready() 跑之前,就已经把主场景的 PackedScene
## 从原始安装包里解析并实例化好了,所以任何"挂到 AutoLoad 里再热更主场景"的方案
## 对主场景本身都是无效的(其它场景没问题,是因为它们是在这一步之后才被加载的)。
##
## 正确顺序是:先在这里把本地已下载的 pck 挂载上,再手动 change_scene_to_file()
## 跳到真正的业务入口(比如 Login/Home),那个场景是"第一次被加载",
## 自然就能读到新资源了。
##
## 请不要往这个场景里加业务逻辑,也不要改动它的节点结构/脚本路径,
## 保持它跨版本长期稳定 —— 它一旦出 bug,只能靠重新发包解决,热更新救不了它。

const PCK_RESOURCE_DIR := "user://packaging/files/"
const PCK_MANIFEST_PATH := "user://packaging/manifest.json"

## 加载完 pck 后真正要进入的入口场景,按你项目实际路径改
@export_file("*.tscn") var target_scene: String = "res://scenes/common/Welcome.tscn"

@onready var status_label: Label = $StatusLabel
@onready var title_label: Label = $TitleLabel

var _spin_angle: float = 0.0
var _pulse_time: float = 0.0
var _spinner_center: Vector2 = Vector2.ZERO
var _spinner_radius: float = 28.0


func _ready() -> void:
    print("Bootstrap.gd _ready() called.")
    _spinner_center = get_viewport_rect().size / 2.0
    _spinner_center.y -= 40.0
    set_process(true)

    # 先等一帧,让 loading 画面真正渲染出来,避免白屏闪一下
    await get_tree().process_frame
    if EnvedLib.editor():
        _set_status("编辑器调试：跳过本地热更新 PCK")
        # await _apply_local_pcks()
    else:
        _set_status("正在加载本地热更新 PCK...")
        await _apply_local_pcks()

    print("获取到的RES构建时间: ", Configuration.getResValue("BUILDED", "build_utc_timestamp", -1))
    print("获取到的RES资源版本号: ", Configuration.getResValue("PACKAGE", "build_pck_vcode", -1))
    
    print("本地热更新 PCK 加载完成,即将进入游戏...")
    await get_tree().create_timer(EnvedLib.editor(1.1, 3.3)).timeout # 休息x秒
    await _goto_target_scene()


func _process(delta: float) -> void:
    _spin_angle += delta * 4.0
    _pulse_time += delta
    title_label.modulate.a = 0.75 + 0.25 * sin(_pulse_time * 2.0)
    queue_redraw()


func _draw() -> void:
    var segments := 24
    for i in range(segments):
        var t := float(i) / float(segments)
        var a := _spin_angle + t * TAU
        var alpha := 1.0 - t
        draw_arc(_spinner_center, _spinner_radius, a, a + 0.18, 8, Color(0.35, 0.75, 1.0, alpha), 4.0, true)


func _set_status(text: String) -> void:
    status_label.text = text
    print(text)


func _apply_local_pcks() -> void:
    var appPckVcode := int(Configuration.getResValue("PACKAGE", "build_pck_vcode", 0))
    Configuration.setUserValue("APP", "last_pck_vcode", appPckVcode)
    Configuration.setUserValue("APP", "last_pck_vname", str(Configuration.getResValue("PACKAGE", "build_pck_vname", "0.0.0")))
    _set_status("正在检查本地资源包...")
    if not FileAccess.file_exists(PCK_MANIFEST_PATH):
        push_warning("更新清单文件不存在,无法加载本地资源包")
        return
    var f := FileAccess.open(PCK_MANIFEST_PATH, FileAccess.READ)
    if f == null:
        push_warning("无法打开更新清单文件,无法加载本地资源包")
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()

    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("更新清单文件格式错误,无法加载本地资源包")
        return

    if not parsed.get("applied", []) is Array:
        push_warning("资源清单的 applied 必须为数组")
        return
    var applied: Array = parsed.get("applied", []).filter(func(entry): return entry is Dictionary)
    applied.sort_custom(func(a, b): return int(a.get("pck_vcode", 0)) < int(b.get("pck_vcode", 0)))
    # Resource packs are process-local mounts: EVERY cold start must mount them again.
    # last_pck_vcode reports the effective version, not a reason to skip mounting.
    for i in range(applied.size()):
        var entry = applied[i]
        var pck_vcode: int = entry.get("pck_vcode", 0)
        var pck_vname: String = entry.get("pck_vname", "0.0.0")
        var pck_filename: String = pck_vname + ".pck"
        if pck_filename == "0.0.0.pck" or pck_vcode <= 0:
            push_warning("更新清单文件中第 %d 个条目格式错误,无法加载本地资源包" % (i + 1))
            continue
        if pck_vcode <= appPckVcode:
            push_warning("更新清单文件中第 %d 个条目版本比打包资源包过低,跳过加载" % (i + 1))
            continue
        if not _valid_version(pck_vname):
            push_warning("资源版本名称无效")
            return
        var path := PCK_RESOURCE_DIR + pck_filename
        _set_status("正在加载资源包 (%d/%d): %s" % [i + 1, applied.size(), pck_filename])
        await get_tree().create_timer(1.0).timeout # 休息2秒
        if not FileAccess.file_exists(path):
            push_warning("本地资源包缺失: %s" % path)
            _set_status("本地资源包缺失: %s" % path)
            return
        var expected_hash := str(entry.get("pck_hash", ""))
        if expected_hash != "" and FileAccess.get_sha256(path).to_lower() != expected_hash.to_lower():
            _set_status("资源包校验失败，将重新检查更新")
            return
        if not ProjectSettings.load_resource_pack(path, true):
            push_warning("加载本地资源包失败: %s" % path)
            _set_status("加载本地资源包失败: %s" % path)
            return
        Configuration.setUserValue("APP", "last_pck_vname", pck_vname)
        Configuration.setUserValue("APP", "last_pck_vcode", pck_vcode)
    
    _set_status("资源加载完成")


func _goto_target_scene() -> void:
    _set_status("正在进入游戏...")
    await get_tree().create_timer(0.2).timeout
    var err := get_tree().change_scene_to_file(target_scene)
    if err != OK:
        push_error("跳转入口场景失败: %s (err=%d)" % [target_scene, err])
        _set_status("启动失败,请重启游戏")

func _valid_version(value: String) -> bool:
    var regex := RegEx.new()
    regex.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")
    return regex.search(value) != null

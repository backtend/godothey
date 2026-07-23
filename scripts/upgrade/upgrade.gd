extends Control

const DOWNLOAD_DIR := "user://updates/"

var _http: HTTPRequest
var _zip_local_path: String
var _apk_local_path: String

@onready var title_label: Label = %TitleLabel
@onready var intro_label: Label = %IntroLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
    # 检查 Updater 单例是否存在（防止因单例缺失直接卡死崩溃）
    if not Engine.has_singleton("Updater") and not get_node_or_null("/root/Updater"):
        push_error("未检测到 Updater 单例！请确保已在 项目设置 -> 自动加载(Autoload) 中注册了 Updater。")
    
    # 设置界面初始化文本
    if "title" in Updater:
        title_label.text = Updater.title
    if "intro" in Updater:
        intro_label.text = Updater.intro
        
    progress_bar.visible = false
    status_label.text = ""
    
    # 强制升级模式判断 (1 为强制升级)
    var upgrade_mode = Updater.upgrade_mode if "upgrade_mode" in Updater else 0
    cancel_button.visible = (upgrade_mode != 1)
    
    if upgrade_mode == 1:
        get_tree().root.set_meta("_block_back", true)
        
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)

func _on_cancel_pressed() -> void:
    get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")

func _on_confirm_pressed() -> void:
    confirm_button.disabled = true
    cancel_button.disabled = true
    progress_bar.visible = true
    progress_bar.value = 0
    status_label.text = "准备下载..."
    await _download_and_install()

func _download_and_install() -> void:
    DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)
    _zip_local_path = DOWNLOAD_DIR + Updater.zip_name

    _http = HTTPRequest.new()
    add_child(_http)
    _http.download_file = _zip_local_path
    _http.use_threads = true
    _http.timeout = 0
    _http.max_redirects = 8

    var progress_timer := Timer.new()
    progress_timer.wait_time = 0.15
    add_child(progress_timer)
    progress_timer.timeout.connect(_update_progress)
    progress_timer.start()

    var err := _http.request(Updater.zip_url)
    if err != OK:
        progress_timer.stop()
        progress_timer.queue_free()
        _fail("下载启动失败，错误码: %s" % err)
        return

    var result: Array = await _http.request_completed
    progress_timer.stop()
    progress_timer.queue_free()

    var http_result: int = result[0]
    var response_code: int = result[1]
    _http.queue_free()

    if http_result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _fail("下载失败，HTTP状态: %s (result=%s)" % [response_code, http_result])
        return

    status_label.text = "校验文件完整性..."
    if not _verify_sha256(_zip_local_path, Updater.zip_hash):
        _fail("文件校验失败(SHA256不匹配)，请重试")
        return

    status_label.text = "解压中..."
    var extract_dir := DOWNLOAD_DIR + "extracted/"
    if not _unzip(_zip_local_path, extract_dir):
        _fail("解压失败")
        return

    _apk_local_path = extract_dir + Updater.dist_name
    if not FileAccess.file_exists(_apk_local_path):
        _fail("未在解压结果中找到安装包: %s" % Updater.dist_name)
        return

    status_label.text = "准备安装..."
    _install_apk(_apk_local_path)

func _update_progress() -> void:
    if not is_instance_valid(_http):
        return
    var total := _http.get_body_size()
    var downloaded := _http.get_downloaded_bytes()
    if total > 0:
        var pct := float(downloaded) / float(total) * 100.0
        progress_bar.value = pct
        status_label.text = "下载中 %d%%" % int(pct)
    else:
        status_label.text = "下载中 %.1f MB" % (downloaded / 1024.0 / 1024.0)

func _verify_sha256(path: String, expected_hash: String) -> bool:
    if expected_hash.is_empty():
        return true
    var actual := FileAccess.get_sha256(path)
    return actual.to_lower() == expected_hash.to_lower()

func _unzip(zip_path: String, target_dir: String) -> bool:
    var reader := ZIPReader.new()
    var err := reader.open(zip_path)
    if err != OK:
        push_warning("打开zip失败: %s" % err)
        return false

    for file_path in reader.get_files():
        if file_path.ends_with("/"):
            DirAccess.make_dir_recursive_absolute(target_dir + file_path)
            continue
        var content := reader.read_file(file_path)
        var out_path := target_dir + file_path
        DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
        var f := FileAccess.open(out_path, FileAccess.WRITE)
        if f == null:
            push_warning("写入文件失败: %s" % out_path)
            reader.close()
            return false
        f.store_buffer(content)
        f.close()

    reader.close()
    return true

func _install_apk(apk_path: String) -> void:
    status_label.text = "正在唤起系统安装程序..."
    if OS.get_name() == "Android":
        if Engine.has_singleton("InstallApk"):
            Engine.get_singleton("InstallApk").install(apk_path)
        else:
            push_warning("未检测到InstallApk插件，尝试shell_open（Android 7.0+上通常无效）")
            OS.shell_open(apk_path)
    else:
        OS.shell_open(apk_path)
    status_label.text = "请在弹出的系统界面中确认安装"

func _fail(msg: String) -> void:
    status_label.text = msg
    confirm_button.disabled = false
    cancel_button.disabled = false
    progress_bar.visible = false

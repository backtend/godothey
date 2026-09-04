extends Control

@onready var title_label: Label = %TitleLabel
@onready var intro_label: Label = %IntroLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var detail_label: Label = %DetailLabel
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var http_request: HTTPRequest = %HTTPRequest

const PCK_RESOURCE_DIR := "user://packaging/files/"
const PCK_MANIFEST_PATH := "user://packaging/manifest.json"

const PCK_MODE_ALL_RESOURCES := "all_resources"
const PCK_MODE_SCENES := "scenes"
const PCK_MODE_RESOURCES := "resources"
const PCK_MODE_EXCLUDE := "exclude"
const PCK_MODE_CUSTOMIZED := "customized"
const VALID_PCK_MODES := [
    PCK_MODE_ALL_RESOURCES, PCK_MODE_SCENES, PCK_MODE_RESOURCES,
    PCK_MODE_EXCLUDE, PCK_MODE_CUSTOMIZED,
]

var _rsp_data: Dictionary = {}
var _update_mode: int = 0
var _packages: Array = []
var _is_updating: bool = false


func _ready() -> void:
    http_request.use_threads = true

    var last_pck_vname: String = Configuration.getUserValue("APP", "last_pck_vname", "")
    print("[Update] 上次已应用的资源包版本: %s" % last_pck_vname)
    if last_pck_vname == "0.0.0" or last_pck_vname == "":
        last_pck_vname = Configuration.getResValue("PACKAGE", "build_pck_vname", "0.2.2")
        print("[Update] 上次已应用的资源包版本为空,尝试从资源配置文件中读取: %s" % last_pck_vname)

    var res: Array = await HttpMdtLib.doPost("/index/checking/update", {
        "project_tag": "godothey", "device_type": "android",
        "last_pck_vname": last_pck_vname,
        "client_uuid": str(Configuration.getUserValue("APP", "client_uuid")),
        "gray_target": "x123123"
    })
    var code: int = res[0]
    var msg: String = res[1]
    var data: Dictionary = res[2]
    _rsp_data = data

    if code != 200:
        push_warning("[Update] 检查更新接口失败: code=%d msg=%s" % [code, msg])
        get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")
        return

    print("[Update] 检查更新接口返回数据: %s" % data)
    _packages = _normalize_packages(data.get("packages", []))
    _update_mode = int(data.get("update_mode", 0))

    if _update_mode == 2:
        print("[Update] 无需更新，直接跳转到登录界面")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")
        return

    title_label.text = data.get("title", "")
    intro_label.text = "[%s]%s" % [ProjectSettings.get_setting("application/config/version", ""), data.get("content", "")]
    status_label.text = ""
    detail_label.text = ""
    progress_bar.value = 0

    match _update_mode:
        1:
            cancel_button.visible = false
            get_tree().root.set_meta("_block_back", true)
        3:
            cancel_button.visible = true
        _:
            push_warning("[Update] 未知的 update_mode: %d,按可选升级处理" % _update_mode)
            cancel_button.visible = true

    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)


func _on_cancel_pressed() -> void:
    if not _is_updating:
        get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")


func _on_confirm_pressed() -> void:
    if _is_updating:
        return
    if _packages.is_empty():
        status_label.text = "没有可更新的资源包"
        return

    _is_updating = true
    confirm_button.disabled = true
    cancel_button.disabled = true

    var ok := await _run_update(_packages)

    if ok:
        _on_all_packages_applied()
        return

    _is_updating = false
    confirm_button.disabled = false
    confirm_button.text = "重试更新"
    cancel_button.disabled = false


# ---------------- 下载核心逻辑 ----------------
# 用一个线性 for 循环 + await 顺序下载每个包,不再需要
# _current_index / _current_pkg / _downloading 这类跨函数、跨信号
# 回调共享的状态。失败就直接 return false,成功就往下走,一眼看到头。

func _run_update(packages: Array) -> bool:
    DirAccess.make_dir_recursive_absolute(PCK_RESOURCE_DIR)

    var total_bytes := 0
    for pkg in packages:
        total_bytes += int(pkg.get("pck_size", 0))

    var applied_tags := _applied_tags(_load_manifest())
    var bytes_done := 0

    print("[Update] 开始下载更新资源包,总大小: %s" % _format_bytes(total_bytes))

    for i in packages.size():
        var pkg: Dictionary = packages[i]
        var tag: String = pkg.get("tag", "")
        var pkg_size := int(pkg.get("pck_size", 0))

        if tag != "" and applied_tags.has(tag):
            print("[Update] 资源包已应用过,跳过下载: tag=%s vname=%s vcode=%d" % [tag, pkg.get("pck_vname", ""), pkg.get("pck_vcode", 0)])
            bytes_done += pkg_size
            continue

        status_label.text = "正在下载更新包 (%d/%d)" % [i + 1, packages.size()]
        print(status_label.text)
        var applied := await _download_and_apply(pkg, i + 1, packages.size(), bytes_done, total_bytes)
        if not applied:
            print("[Update] 下载资源包失败,中止更新: tag=%s vname=%s vcode=%d" % [tag, pkg.get("pck_vname", ""), pkg.get("pck_vcode", 0)])
            return false

        bytes_done += pkg_size

    print("[Update] 所有资源包已下载并应用完毕: %d 个包" % packages.size())
    return true


func _download_and_apply(pkg: Dictionary, index: int, total_count: int, bytes_before: int, total_bytes: int) -> bool:
    var pck_filename: String = pkg.get("pck_vname") + ".pck"
    var dest_path := PCK_RESOURCE_DIR + pck_filename
    var pkg_size := int(pkg.get("pck_size", 0))

    http_request.download_file = dest_path
    print("[Update] 开始下载资源包 (%d/%d): %s" % [index, total_count, pck_filename])

    var request_err := http_request.request(pkg.get("pck_url", ""))
    if request_err != OK:
        push_error("[Update] 下载请求发起失败: url=%s err=%d" % [pkg.get("pck_url", ""), request_err])
        _fail("下载请求发起失败,错误码: %d" % request_err)
        return false

    # 进度条轮询独立成一个短命协程,靠 stop[0] 这个共享数组结束自己,
    # 不再依赖 _process() 里的全局 _downloading 开关。
    var stop_progress := [false]
    _poll_progress(bytes_before, total_bytes, pkg_size, stop_progress)

    var result: Array = await http_request.request_completed
    stop_progress[0] = true

    var http_result: int = result[0]
    var response_code: int = result[1]

    if http_result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        push_error("[Update] 下载失败: result=%d code=%d pkg=%s" % [http_result, response_code, pkg.get("pck_name", "")])
        _fail("下载失败 (result=%d, code=%d),请检查网络后重试" % [http_result, response_code])
        return false

    if not FileAccess.file_exists(dest_path):
        push_error("[Update] 下载完成但文件不存在: %s" % dest_path)
        _fail("下载完成但文件不存在: %s" % dest_path)
        return false

    print("[Update] 资源包下载成功，存储在: %s" % dest_path)

    var expected_hash: String = str(pkg.get("pck_hash", "abcdefg")).strip_edges()
    status_label.text = "正在校验更新包..."
    var actual_hash := _sha256_hex(dest_path)
    if actual_hash.to_lower() != expected_hash.to_lower():
        push_error("[Update] 哈希校验失败: pkg=%s 期望=%s 实际=%s" % [pck_filename, expected_hash, actual_hash])
        _fail("更新包校验失败,可能已损坏,请重试")
        # 删除损坏的文件,避免下次启动时重复校验失败
        if FileAccess.file_exists(dest_path):
            var del_err: Error = DirAccess.remove_absolute(dest_path)
            if del_err != OK:
                push_warning("[Update] 删除损坏的资源包失败: %s (err=%d)" % [dest_path, del_err])
        return false

    # 挂载到虚拟文件系统,主要用于校验 pck 本身是否有效可加载;
    # 真正让新资源生效依赖下次冷启动时 AutoLoad 重新挂载,这里不做热替换。
    if not ProjectSettings.load_resource_pack(dest_path, true):
        push_error("[Update] 加载资源包失败: %s" % dest_path)
        _fail("加载资源包失败: %s" % pck_filename)
        return false

    # 全量包成功写入并加载后,它之前的所有资源包都已经失效,此时再安全清理。
    if _is_all_resources_package(pkg):
        _reset_manifest_from_full_package(pkg)

    _record_applied(pkg)
    return true


func _poll_progress(bytes_before: int, total_bytes: int, pkg_size: int, stop: Array) -> void:
    while not stop[0]:
        var downloaded := http_request.get_downloaded_bytes()
        var overall_done := bytes_before + downloaded

        if total_bytes > 0:
            progress_bar.value = (float(overall_done) / float(total_bytes)) * 100.0

        var pct := 0.0 if pkg_size <= 0 else (float(downloaded) / float(pkg_size)) * 100.0
        detail_label.text = "%s / %s  (%.0f%%)" % [_format_bytes(downloaded), _format_bytes(pkg_size), pct]

        await get_tree().create_timer(0.1).timeout


func _fail(msg: String) -> void:
    status_label.text = msg
    detail_label.text = ""
    print("[Update] 更新失败: %s" % msg)


func _on_all_packages_applied() -> void:
    Configuration.setUserValue("APP", "last_pck_vname", str(_rsp_data.get("latest_version_name", "0.0.0")))
    Configuration.setUserValue("APP", "last_pck_vcode", str(_rsp_data.get("latest_version_code", 0)))
    status_label.text = "更新完成,即将重新打开..."
    detail_label.text = ""
    progress_bar.value = 100
    await get_tree().create_timer(1.8).timeout
    _hard_restart()


# 新 pck 已经写入本地并记录进 manifest,但让新资源真正生效依赖
# 冷启动时 AutoLoad(挂载顺序最靠前的那个)重新 load_resource_pack。
# 同进程内用 CACHE_MODE_REPLACE 热替换 Main.tscn 在部分导出配置下会
# 因为该资源属于内置基础包、无法被重新 open 而报错,故不采用该方案,
# 统一走"重启进程"路径,桌面端自动重启,Android 端提示手动重开。
func _hard_restart() -> void:
    match OS.get_name():
        "Windows", "macOS", "Linux", "X11":
            OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
            get_tree().quit()
        _:
            status_label.text = "更新完成,请手动重新打开应用"
            await get_tree().create_timer(2.5).timeout
            get_tree().quit()


# ---------------- 本地清单持久化 ----------------

func _record_applied(pkg: Dictionary) -> void:
    var manifest := _load_manifest()
    var applied: Array = manifest.get("applied", [])
    applied.append({
        "tag": pkg.get("tag", ""),
        "pck_name": pkg.get("pck_name", ""),
        "pck_mode": pkg.get("pck_mode", ""),
        "pck_vname": pkg.get("pck_vname", 0),
        "pck_vcode": pkg.get("pck_vcode", 0)
    })
    manifest["applied"] = applied
    manifest["last_pck_vcode"] = pkg.get("pck_vcode", manifest.get("last_pck_vcode", 0))
    _save_manifest(manifest)


func _applied_tags(manifest: Dictionary) -> Array:
    var tags: Array = []
    for entry in manifest.get("applied", []):
        tags.append(entry.get("tag", ""))
    return tags


func _load_manifest() -> Dictionary:
    if not FileAccess.file_exists(PCK_MANIFEST_PATH):
        return {"applied": []}
    var f := FileAccess.open(PCK_MANIFEST_PATH, FileAccess.READ)
    if f == null:
        push_warning("[Update] 无法打开更新清单文件: %s (err=%d)" % [PCK_MANIFEST_PATH, FileAccess.get_open_error()])
        return {"applied": []}
    var text := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("[Update] 更新清单文件格式错误,已忽略: %s" % PCK_MANIFEST_PATH)
        return {"applied": []}
    if not parsed.has("applied"):
        parsed["applied"] = []
    return parsed


func _save_manifest(manifest: Dictionary) -> void:
    var f := FileAccess.open(PCK_MANIFEST_PATH, FileAccess.WRITE)
    if f == null:
        push_error("[Update] 无法写入更新清单文件: %s (err=%d)" % [PCK_MANIFEST_PATH, FileAccess.get_open_error()])
        return
    f.store_string(JSON.stringify(manifest))
    f.close()


# ---------------- 工具函数 ----------------

func _normalize_packages(packages: Array) -> Array:
    if packages.is_empty():
        return []

    var last_all_resources_index := -1
    for i in packages.size():
        var pkg: Dictionary = packages[i]
        var pck_mode := str(pkg.get("pck_mode", "")).strip_edges()
        if not VALID_PCK_MODES.has(pck_mode):
            push_warning("[Update] 未知 pck_mode=%s, tag=%s" % [pck_mode, pkg.get("tag", "")])
        if pck_mode == PCK_MODE_ALL_RESOURCES:
            last_all_resources_index = i

    if last_all_resources_index < 0:
        return packages

    print("[Update] 使用全量资源包作为资源基线: tag=%s, index=%d" % [
        str(packages[last_all_resources_index].get("tag", "")).strip_edges(), last_all_resources_index
    ])
    return packages.slice(last_all_resources_index)


func _is_all_resources_package(pkg: Dictionary) -> bool:
    return str(pkg.get("pck_mode", "")).strip_edges() == PCK_MODE_ALL_RESOURCES


func _reset_manifest_from_full_package(full_pkg: Dictionary) -> void:
    var manifest := _load_manifest()
    var applied: Array = manifest.get("applied", [])
    var full_tag := str(full_pkg.get("tag", "")).strip_edges()

    if full_tag == "":
        push_warning("[Update] all_resources 缺少 tag,无法精确清理旧 manifest")
        return

    var new_applied: Array = []
    var found_full := false

    for entry in applied:
        var tag := str(entry.get("tag", ""))
        if tag == full_tag:
            found_full = true
            new_applied.append(entry)
        elif found_full:
            new_applied.append(entry)
        else:
            _delete_local_package(entry)

    # 如果旧 manifest 中没有这个全量包,说明它是新的资源基线,旧 applied 全部失效。
    if not found_full:
        for entry in applied:
            _delete_local_package(entry)
        new_applied.clear()

    manifest["applied"] = new_applied
    _save_manifest(manifest)


func _delete_local_package(entry: Dictionary) -> void:
    var pck_filename := str(entry.get("pck_vname") + ".pck").strip_edges()
    if pck_filename == "":
        return

    var path := PCK_RESOURCE_DIR + pck_filename
    if not FileAccess.file_exists(path):
        return

    var err := DirAccess.remove_absolute(path)
    if err != OK:
        push_warning("[Update] 删除旧资源包失败: path=%s err=%d" % [path, err])
    else:
        push_warning("[Update] 已删除旧资源包: %s" % path)


func _sha256_hex(path: String) -> String:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("[Update] 计算哈希时无法打开文件: %s (err=%d)" % [path, FileAccess.get_open_error()])
        return ""
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    while not f.eof_reached():
        var chunk := f.get_buffer(65536)
        if chunk.size() > 0:
            ctx.update(chunk)
    f.close()
    return ctx.finish().hex_encode()


func _format_bytes(bytes: int) -> String:
    if bytes >= 1024 * 1024:
        return "%.1fMB" % (float(bytes) / (1024.0 * 1024.0))
    elif bytes >= 1024:
        return "%.1fKB" % (float(bytes) / 1024.0)
    else:
        return "%dB" % bytes

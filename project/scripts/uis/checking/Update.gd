extends Control

@onready var title_label: Label = %TitleLabel
@onready var intro_label: Label = %IntroLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var detail_label: Label = %DetailLabel
@onready var status_label: Label = %StatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var http_request: HTTPRequest = %HTTPRequest

const PCK_DIR := "user://update_pcks/"
const MANIFEST_PATH := "user://update_manifest.json"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
# 除 Main.tscn 外,还有哪些"早于本场景加载"的资源需要在更新后强制刷新缓存,按需追加
const EXTRA_RELOAD_PATHS: Array[String] = []

var _rsp_data: Dictionary = {}
var _update_mode: int = 0
var _packages: Array = []

var _is_updating: bool = false
var _downloading: bool = false
var _current_index: int = 0
var _current_pkg: Dictionary = {}
var _total_bytes: int = 0
var _bytes_before_current: int = 0


func _ready() -> void:
	http_request.use_threads = true
	http_request.request_completed.connect(_on_request_completed)

	var res: Array = await HttpMdtLib.doPost("/index/checking/update", {
		"project_tag": "godothey", "device_type": "android",
		"version_name": Configuration.get_val("APP", "package_latest_version_name", "0.0.0"),
		"client_uuid": str(Configuration.get_val("APP", "client_uuid")),
		"gray_target": "x123123"
	})
	var _code: int = res[0]; var _msg: String = res[1]; var _data: Dictionary = res[2]
	_rsp_data = _data
	if _code != 200:
		push_warning(_msg)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/home/Home.tscn")
		return

	_packages = _data.get("packages", [])
	_update_mode = int(_data.get("update_mode", 0))
	if _update_mode == 2:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")
		return

	title_label.text = _data.get("title", "")
	intro_label.text = "[%s]%s" % [ProjectSettings.get_setting("application/config/version", ""), _data.get("content", "")]
	status_label.text = ""; detail_label.text = ""; progress_bar.value = 0

	match _update_mode:
		1:
			cancel_button.visible = false
			get_tree().root.set_meta("_block_back", true)
		3:
			cancel_button.visible = true
		_:
			push_warning("未知的 update_mode: %d,按可选升级处理" % _update_mode)
			cancel_button.visible = true

	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func _process(_delta: float) -> void:
	if not _downloading:
		return
	var downloaded := http_request.get_downloaded_bytes()
	var body_size := http_request.get_body_size()
	var pkg_size := int(_current_pkg.get("pck_size", body_size if body_size > 0 else 0))

	var overall_done := _bytes_before_current + downloaded
	if _total_bytes > 0:
		progress_bar.value = (float(overall_done) / float(_total_bytes)) * 100.0

	var pct := 0.0 if pkg_size <= 0 else (float(downloaded) / float(pkg_size)) * 100.0
	detail_label.text = "%s / %s  (%.0f%%)" % [_format_bytes(downloaded), _format_bytes(pkg_size), pct]


func _on_cancel_pressed() -> void:
	if not _is_updating:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/auth/Login.tscn")


func _on_confirm_pressed() -> void:
	if _is_updating:
		return
	if _packages.is_empty():
		status_label.text = "没有可更新的资源包"
		return
	_start_update()


# ---------------- 更新下载核心逻辑 ----------------

func _start_update() -> void:
	_is_updating = true
	confirm_button.disabled = true
	cancel_button.disabled = true

	DirAccess.make_dir_recursive_absolute(PCK_DIR)
	_total_bytes = 0
	for pkg in _packages:
		_total_bytes += int(pkg.get("pck_size", 0))
	_bytes_before_current = 0
	_current_index = 0
	_download_next()


func _download_next() -> void:
	if _current_index >= _packages.size():
		_on_all_packages_applied()
		return

	var pkg: Dictionary = _packages[_current_index]
	var tag: String = pkg.get("tag", "")

	# 如果这个包之前已经下载并应用过(比如上次更新中途被打断),跳过重复下载
	var applied_tags := _applied_tags(_load_manifest())
	if tag != "" and applied_tags.has(tag):
		_bytes_before_current += int(pkg.get("pck_size", 0))
		_current_index += 1
		_download_next()
		return

	_current_pkg = pkg
	var pck_name: String = pkg.get("pck_name", "pkg_%d.pck" % _current_index)
	status_label.text = "正在下载更新包 (%d/%d)" % [_current_index + 1, _packages.size()]
	http_request.download_file = PCK_DIR + pck_name
	_downloading = true

	var err := http_request.request(pkg.get("pck_url", ""))
	if err != OK:
		_downloading = false
		_on_update_failed("下载请求发起失败,错误码: %d" % err)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_on_update_failed("下载失败 (result=%d, code=%d),请检查网络后重试" % [result, response_code])
		return

	var pck_name: String = _current_pkg.get("pck_name", "")
	var dest_path := PCK_DIR + pck_name
	var expected_hash: String = str(_current_pkg.get("pck_hash", "")).strip_edges()

	if not FileAccess.file_exists(dest_path):
		_on_update_failed("下载完成但文件不存在: %s" % dest_path)
		return

	if expected_hash != "":
		status_label.text = "正在校验更新包..."
		var actual_hash := _sha256_hex(dest_path)
		if actual_hash.to_lower() != expected_hash.to_lower():
			push_warning("哈希校验失败: 期望 %s, 实际 %s" % [expected_hash, actual_hash])
			_on_update_failed("更新包校验失败,可能已损坏,请重试")
			return

	if not ProjectSettings.load_resource_pack(dest_path, true):
		_on_update_failed("加载资源包失败: %s" % pck_name)
		return

	_record_applied(_current_pkg)
	_bytes_before_current += int(_current_pkg.get("pck_size", 0))
	_current_index += 1
	_download_next()


func _on_update_failed(msg: String) -> void:
	status_label.text = msg
	detail_label.text = ""
	_is_updating = false
	confirm_button.disabled = false
	confirm_button.text = "重试更新"
	cancel_button.disabled = false


func _on_all_packages_applied() -> void:
	Configuration.set_val("APP", "package_latest_version_name", str(_rsp_data.get("latest_version_name", "0.0.0")))
	Configuration.set_val("APP", "package_latest_version_code", str(_rsp_data.get("latest_version_code", 0)))
	status_label.text = "更新完成,正在应用..."
	detail_label.text = ""
	progress_bar.value = 100
	await get_tree().create_timer(0.5).timeout
	_apply_update_and_continue()


# 新 pck 已经通过 load_resource_pack 挂载到虚拟文件系统了,
# 但 Main.tscn 这类"早于本场景"加载的资源在本进程内已被缓存成旧版本,
# 用 CACHE_MODE_REPLACE 强制丢弃旧缓存、重新读取,免去重启整个 App 的需求
# (这一步也顺带解决了 Android 上 quit() 后无法自动重新打开的问题)。
func _apply_update_and_continue() -> void:
	for path in EXTRA_RELOAD_PATHS:
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var main_scene: PackedScene = ResourceLoader.load(MAIN_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	get_tree().call_deferred("change_scene_to_packed", main_scene)


# 可选:如果某次更新改动了 AutoLoad 单例脚本自身的逻辑代码,
# 上面的原地刷新是无法热替换单例实例的,这种情况才需要真正重启进程。
# 桌面平台可行;Android 目前只能提示用户手动重新打开(Godot 无内置重启 API)。
func _hard_restart() -> void:
	match OS.get_name():
		"Windows", "macOS", "Linux", "X11":
			OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
			get_tree().quit()
		_:
			status_label.text = "更新完成,请手动重新打开应用"
			get_tree().quit()


# ---------------- 本地清单持久化 ----------------

func _record_applied(pkg: Dictionary) -> void:
	var manifest := _load_manifest()
	var applied: Array = manifest.get("applied", [])
	applied.append({
		"tag": pkg.get("tag", ""),
		"pck_name": pkg.get("pck_name", ""),
		"version_code": pkg.get("version_code", 0)
	})
	manifest["applied"] = applied
	manifest["version_code"] = pkg.get("version_code", manifest.get("version_code", 0))
	_save_manifest(manifest)


func _applied_tags(manifest: Dictionary) -> Array:
	var tags: Array = []
	for entry in manifest.get("applied", []):
		tags.append(entry.get("tag", ""))
	return tags


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"applied": []}
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return {"applied": []}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"applied": []}
	if not parsed.has("applied"):
		parsed["applied"] = []
	return parsed


func _save_manifest(manifest: Dictionary) -> void:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入更新清单文件")
		return
	f.store_string(JSON.stringify(manifest))
	f.close()


# ---------------- 工具函数 ----------------

func _sha256_hex(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
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
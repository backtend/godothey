# scripts/libs/HttpMdtLib.gd
# MDT 请求帮助类（对称加密）
# 里程碑记：任何情况都不会抛异常！解构四个参数 code, msg, data, rid
# 移植自 Python HttpMdt v26.522.1419
# 适配 Godot 4.x（使用 HTTPRequest + await）

class_name HttpMdtLib
extends RefCounted

## 基础 URL（优先读环境变量 HTTPX_MDT_URL）
static var BASE_URL: String = _get_env("HTTPX_MDT_URL", "")

## MDT 密钥（优先读环境变量 HTTPX_MDT_SECRET）
## 也可通过 ProjectSettings 设置：application/config/mdt_secret
## 运行时可覆盖：HttpMdtLib.MDT_SECRET = "xxx"
static var MDT_SECRET: String = ""


## 发送 POST 请求，支持自定义 headers，支持单文件/多文件上传（multipart）
## 返回 [code, msg, data, rid]  永远不会抛异常
## options 可传：
##   - "mdt_secret": 覆盖默认密钥
##   - "timeout": 超时秒数（默认 15）
##   - "headers": Dictionary 或 PackedStringArray 额外请求头
static func post(url: String, data: Dictionary = {}, options: Dictionary = {}) -> Array:
	var mdt_secret := str(options.get("mdt_secret", _get_mdt_secret()))
	var timeout: float = float(options.get("timeout", 15.0))

	var headers := PackedStringArray([
		"Authorization: Token %s" % generate_authorization(mdt_secret),
		"Accept: application/json",
		"Content-Type: application/json",
	])

	# 合并用户传入的 headers
	if options.has("headers") and options["headers"] is Dictionary:
		for k in options["headers"]:
			headers.append("%s: %s" % [str(k), str(options["headers"][k])])
	elif options.has("headers") and options["headers"] is PackedStringArray:
		headers.append_array(options["headers"])

	var payload := data.duplicate(true)

	# 判断是否有文件（单文件 or 多文件）
	var is_multipart := false
	var upload_file = null
	var upload_files: Array = []

	if payload.has("upload_file"):
		upload_file = payload["upload_file"]
		payload.erase("upload_file")
		is_multipart = true
		headers = _remove_header(headers, "Content-Type")
	elif payload.has("upload_files"):
		upload_files = payload["upload_files"]
		payload.erase("upload_files")
		is_multipart = true
		headers = _remove_header(headers, "Content-Type")

	# 拼接完整 URL
	var full_url := url
	if not url.begins_with("http"):
		full_url = BASE_URL + url.lstrip(".")
	if not full_url.begins_with("http"):
		return [400, "无效的请求URL", {}, Time.get_unix_time_from_system()]

	# 创建临时 HTTPRequest
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return [500, "RequestError: SceneTree not available", {}, Time.get_unix_time_from_system()]

	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true
	tree.root.add_child(http)

	var body: PackedByteArray

	if is_multipart:
		var boundary := "----GodotFormBoundary%s" % str(Time.get_ticks_msec())
		headers.append("Content-Type: multipart/form-data; boundary=%s" % boundary)
		body = _build_multipart_body(payload, upload_file, upload_files, boundary)
	else:
		body = JSON.stringify(payload).to_utf8_buffer()

	var err := http.request_raw(full_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return [500, "RequestError: HTTPRequest failed to start (%s)" % error_string(err), {}, Time.get_unix_time_from_system()]

	var result = await http.request_completed
	http.queue_free()

	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		return [500, "RequestError: %s" % _http_result_to_str(http_result), {}, Time.get_unix_time_from_system()]

	if response_code != 200:
		var _text := response_body.get_string_from_utf8()
		return [500, "请求失败，状态码: %d, 原因: %s" % [response_code, _text], {}, Time.get_unix_time_from_system()]

	var text := response_body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return [500, "非JSON响应:%s" % text, {}, Time.get_unix_time_from_system()]

	var res: Variant = json.get_data()
	if typeof(res) != TYPE_DICTIONARY:
		return [500, "非JSON对象响应:%s" % text, {}, Time.get_unix_time_from_system()]

	var code = res.get("code", 505)
	var msg = res.get("msg", "(messageEmpty)")
	var data_res = res.get("data", {})
	var rid = res.get("rid", Time.get_unix_time_from_system())

	return [code, msg, data_res, rid]


## 生成双重 MD5 + Base64 的 Authorization 字段
## 算法：md5(md5(secret + timestamp)) + "," + timestamp  → Base64
static func generate_authorization(mdt_secret: String = "") -> String:
	if mdt_secret.is_empty():
		mdt_secret = _get_mdt_secret()

	var timestamp := str(int(Time.get_unix_time_from_system()))
	# var timestamp := "1763628248"  # 测试固定时间戳

	var raw := str(mdt_secret) + timestamp
	var md5_1 := _md5_hex(raw)
	var md5_2 := _md5_hex(md5_1)

	var merged := "%s,%s" % [md5_2, timestamp]
	return Marshalls.raw_to_base64(merged.to_utf8_buffer())


#region 内部工具

static func _get_mdt_secret() -> String:
	# 1. 运行时直接赋值优先
	if not MDT_SECRET.is_empty():
		return MDT_SECRET
	# 2. ProjectSettings
	#    ProjectSettings.set_setting("application/config/mdt_secret", "你的密钥")
	var from_ps := str(ProjectSettings.get_setting("application/config/mdt_secret", ""))
	if not from_ps.is_empty():
		return from_ps
	# 3. 环境变量
	return _get_env("HTTPX_MDT_SECRET", "")


static func _get_env(key: String, default: String = "") -> String:
	if OS.has_environment(key):
		return OS.get_environment(key)
	return default


static func _md5_hex(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func _remove_header(headers: PackedStringArray, name: String) -> PackedStringArray:
	var lower_name := name.to_lower()
	var new_headers: PackedStringArray = []
	for h in headers:
		if not h.to_lower().begins_with(lower_name + ":"):
			new_headers.append(h)
	return new_headers


static func _http_result_to_str(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "TIMEOUT"
		_:
			return "UNKNOWN(%d)" % result


## 构建 multipart/form-data 请求体
static func _build_multipart_body(fields: Dictionary, upload_file, upload_files: Array, boundary: String) -> PackedByteArray:
	var body := PackedByteArray()
	var crlf := "\r\n".to_utf8_buffer()
	var boundary_line := ("--" + boundary).to_utf8_buffer()
	var end_boundary := ("--" + boundary + "--\r\n").to_utf8_buffer()

	# 普通字段
	for key in fields:
		body.append_array(boundary_line)
		body.append_array(crlf)
		body.append_array(('Content-Disposition: form-data; name="%s"' % str(key)).to_utf8_buffer())
		body.append_array(crlf)
		body.append_array(crlf)
		body.append_array(str(fields[key]).to_utf8_buffer())
		body.append_array(crlf)

	# 单文件
	if upload_file != null:
		_append_file_part(body, boundary_line, crlf, "upload_file", upload_file)

	# 多文件
	for f in upload_files:
		_append_file_part(body, boundary_line, crlf, "upload_files[]", f)

	body.append_array(end_boundary)
	return body


static func _append_file_part(body: PackedByteArray, boundary_line: PackedByteArray, crlf: PackedByteArray, field_name: String, file_obj) -> void:
	var file_bytes: PackedByteArray
	var filename := "file.bin"

	if file_obj is FileAccess:
		file_bytes = file_obj.get_buffer(file_obj.get_length())
		filename = file_obj.get_path().get_file()
	elif file_obj is PackedByteArray:
		file_bytes = file_obj
	elif file_obj is String:
		if FileAccess.file_exists(file_obj):
			var fa := FileAccess.open(file_obj, FileAccess.READ)
			if fa:
				file_bytes = fa.get_buffer(fa.get_length())
				filename = file_obj.get_file()
				fa.close()
			else:
				file_bytes = PackedByteArray()
		else:
			file_bytes = PackedByteArray()
	else:
		if file_obj is Dictionary and file_obj.has("data"):
			file_bytes = file_obj["data"]
			filename = str(file_obj.get("name", filename))
		else:
			file_bytes = PackedByteArray()

	body.append_array(boundary_line)
	body.append_array(crlf)
	body.append_array(('Content-Disposition: form-data; name="%s"; filename="%s"' % [field_name, filename]).to_utf8_buffer())
	body.append_array(crlf)
	body.append_array("Content-Type: application/octet-stream".to_utf8_buffer())
	body.append_array(crlf)
	body.append_array(crlf)
	body.append_array(file_bytes)
	body.append_array(crlf)

#endregion
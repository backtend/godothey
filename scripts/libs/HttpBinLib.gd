# scripts/libs/HttpBinLib.gd
# 通用 HTTP 请求帮助类
# 任何情况都不会抛异常！返回 [code, msg, data, rid]
# 适配 Godot 4.x（使用 HTTPRequest + await）
# 精简版：仅支持 JSON 请求（doPost / doGet），无模块级状态

class_name HttpBinLib
extends RefCounted


## 快捷 POST
## options 可传："timeout"(秒,默认15), "headers"(Dictionary), "base_url"(默认读环境变量 HTTP_BASE_URL)
static func doPost(url: String, data: Dictionary = {}, options: Dictionary = {}) -> Array:
	options["method"] = HTTPClient.METHOD_POST
	return await request(url, data, options)


## 快捷 GET
## data 会作为查询参数拼接到 URL 上（?k=v&k2=v2）
static func doGet(url: String, data: Dictionary = {}, options: Dictionary = {}) -> Array:
	options["method"] = HTTPClient.METHOD_GET
	return await request(url, data, options)


## 发送请求，返回 [code, msg, data, rid]，永远不会抛异常
static func request(url: String, data: Dictionary = {}, options: Dictionary = {}) -> Array:
	var timeout: float = float(options.get("timeout", 15.0))
	var method: int = options.get("method", HTTPClient.METHOD_POST)
	var base_url: String = options.get("base_url", _get_env("HTTP_BASE_URL", "https://godot.yongit.com"))

	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json",
	])
	if options.has("headers") and options["headers"] is Dictionary:
		for k in options["headers"]:
			headers.append("%s: %s" % [str(k), str(options["headers"][k])])
	elif options.has("headers") and options["headers"] is PackedStringArray:
		headers.append_array(options["headers"])

	var is_body_method := not (method == HTTPClient.METHOD_GET or method == HTTPClient.METHOD_HEAD)
	if not is_body_method:
		headers = _remove_header(headers, "Content-Type")

	# 拼接完整 URL
	var full_url := url
	if not url.begins_with("http"):
		full_url = base_url + url.lstrip(".")
	if not full_url.begins_with("http"):
		return [400, "无效的请求URL", {}, Time.get_unix_time_from_system()]

	# GET/HEAD：把 data 拼成查询参数
	if not is_body_method and not data.is_empty():
		full_url += ("&" if full_url.contains("?") else "?") + _build_query_string(data)

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return [500, "RequestError: SceneTree not available", {}, Time.get_unix_time_from_system()]

	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true
	tree.root.add_child(http)

	var body: PackedByteArray = PackedByteArray()
	if is_body_method:
		body = JSON.stringify(data).to_utf8_buffer()

	var err := http.request_raw(full_url, headers, method, body)
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

	if response_code < 200 or response_code >= 300:
		var _text := response_body.get_string_from_utf8()
		return [response_code, "请求失败，状态码: %d, 原因: %s" % [response_code, _text], {}, Time.get_unix_time_from_system()]

	var text := response_body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return [response_code, "非JSON响应", {"raw": text}, Time.get_unix_time_from_system()]

	var res: Variant = json.get_data()

	# 兼容两种常见返回格式：
	# 1. 标准 {code, msg, data, rid}
	# 2. 直接返回业务数据
	if typeof(res) == TYPE_DICTIONARY:
		var code = res.get("code", response_code)
		var msg = res.get("msg", res.get("message", "ok"))
		var data_res = res.get("data", res)
		var rid = res.get("rid", Time.get_unix_time_from_system())
		return [code, msg, data_res, rid]
	else:
		return [response_code, "ok", res, Time.get_unix_time_from_system()]


#region 内部工具

static func _get_env(key: String, default: String = "") -> String:
	if OS.has_environment(key):
		return OS.get_environment(key)
	return default


static func _remove_header(headers: PackedStringArray, name: String) -> PackedStringArray:
	var lower_name := name.to_lower()
	var new_headers: PackedStringArray = []
	for h in headers:
		if not h.to_lower().begins_with(lower_name + ":"):
			new_headers.append(h)
	return new_headers


static func _build_query_string(data: Dictionary) -> String:
	var parts: Array[String] = []
	for k in data:
		parts.append("%s=%s" % [String(k).uri_encode(), str(data[k]).uri_encode()])
	return "&".join(parts)


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

#endregion
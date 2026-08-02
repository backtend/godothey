class_name UpgradeLogic
extends RefCounted

## 升级检查 + 跳转下载页逻辑，不持有状态，所有依赖通过参数传入

const CHECK_URL := "https://apix.yongit.com/programer/check"

# 拼装升级检查接口的完整 URL
static func build_check_url() -> String:
    var params := {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": ProjectSettings.get_setting("application/config/version", ""),
        "gray_target": ""
    }
    var query_parts := PackedStringArray()
    for key in params:
        query_parts.append("%s=%s" % [key.uri_encode(), str(params[key]).uri_encode()])
    return "%s?%s" % [CHECK_URL, "&".join(query_parts)]


# 请求升级检查接口
# 返回 {"success": bool, "error": String, "data": Dictionary}
static func check_upgrade(node: Node) -> Dictionary:
    var http := HTTPRequest.new()
    node.add_child(http)

    var err := http.request(build_check_url())
    if err != OK:
        http.queue_free()
        return {"success": false, "error": "升级检查请求发起失败: %s" % err, "data": {}}

    var result: Array = await http.request_completed
    http.queue_free()

    var http_result: int = result[0]
    var response_code: int = result[1]
    var body: PackedByteArray = result[3]

    if http_result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        return {"success": false, "error": "升级检查网络错误，HTTP状态: %s" % response_code, "data": {}}

    var json := JSON.new()
    var parse_err := json.parse(body.get_string_from_utf8())
    if parse_err != OK:
        return {"success": false, "error": "升级检查JSON解析失败: %s" % json.get_error_message(), "data": {}}

    var res: Dictionary = json.get_data()
    if res.get("code", -1) != 200:
        return {"success": false, "error": "升级检查业务错误: %s" % res.get("msg", ""), "data": {}}

    return {"success": true, "error": "", "data": res.get("data", {})}


# 用系统浏览器打开下载/发布地址
static func open_release_url(url: String) -> bool:
    if url.is_empty():
        push_warning("release_url 为空，无法跳转")
        return false
    return OS.shell_open(url) == OK
class_name WelcomeLogic
extends RefCounted

# const DEVICE_TYPE := "android"


# 初始化
static func initial(node: Node) -> String:
    var http := HTTPRequest.new()
    node.add_child(http)

    var err := http.request(_build_initial_url())
    if err != OK:
        http.queue_free()
        print("初始化请求发起失败: %s" % err)
        return "res://scenes/home/Home.tscn"

    var result: Array = await http.request_completed
    http.queue_free()

    var http_result: int = result[0]
    var response_code: int = result[1]
    var body: PackedByteArray = result[3]

    if http_result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        print("初始化网络错误，HTTP状态: %s" % response_code)
        return "res://scenes/home/Home.tscn"

    var json := JSON.new()
    var parse_err := json.parse(body.get_string_from_utf8())
    if parse_err != OK:
        print("初始化JSON解析失败: %s" % json.get_error_message())
        return "res://scenes/home/Home.tscn"

    print("初始化JSON解析成功: %s" % json.get_data())

    var res: Dictionary = json.get_data()
    if res.get("code", -1) != 200:
        print("初始化业务错误: %s" % res.get("msg", ""))
        return "res://scenes/home/Home.tscn"

    var data: Dictionary = res.get("data", {})
    print("初始化返回数据: %s" % data)

    # 是否需要升级
    if data.get("need_upgrade", false):
        print("需要升级，即将前往升级中心")
        return "res://scenes/upgrade/Upgrade.tscn"
        

    # 是否登录状态 
    if data.get("current_login", false):
        print("用户已登录，跳转到主界面")
        return "res://scenes/home/Home.tscn"
        
    print("用户未登录，跳转到登录界面")
    return "res://scenes/auth/Login.tscn"


# 拼装升级检查接口的完整 URL
static func _build_initial_url() -> String:
    var versionName: String = ProjectSettings.get_setting("application/config/version", "")
    var clientUuid := str(Configuration.get_val("clientuuid"))
    var params := {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": versionName,
        "client_uuid": clientUuid,
        "gray_target": "x123123"
    }
    var queryParts := PackedStringArray()
    for key in params:
        queryParts.append("%s=%s" % [key.uri_encode(), str(params[key]).uri_encode()])
    const CHECK_URL := "https://godot.yongit.com/index/initial"
    return "%s?%s" % [CHECK_URL, "&".join(queryParts)]

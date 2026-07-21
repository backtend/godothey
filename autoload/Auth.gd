extends Node

const TOKEN_PATH := "user://jwt_token.dat"
const CHECK_URL := "https://godot.yongit.com/system/check"
const LOGIN_URL := "https://godot.yongit.com/auth/login"

signal check_login_success
signal check_login_failed
signal login_success
signal login_failed(msg: String)

var token: String = ""

func _ready() -> void:
    token = _load_token()

func has_token() -> bool:
    return token != ""

func _load_token() -> String:
    if not FileAccess.file_exists(TOKEN_PATH):
        return ""
    var f := FileAccess.open(TOKEN_PATH, FileAccess.READ)
    if f == null:
        return ""
    var t := f.get_as_text()
    f.close()
    return t.strip_edges()

func _save_token(t: String) -> void:
    var f := FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
    if f:
        f.store_string(t)
        f.close()
    token = t

func clear_token() -> void:
    if FileAccess.file_exists(TOKEN_PATH):
        DirAccess.remove_absolute(TOKEN_PATH)
    token = ""

# ---------- 启动时校验 token ----------
func check_login() -> void:
    if not has_token():
        check_login_failed.emit()
        return
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_check_completed.bind(http))
    var headers := ["Authorization: Bearer %s" % token, "Content-Type: application/json"]
    var err := http.request(CHECK_URL, headers, HTTPClient.METHOD_GET)
    print("请求URL: ", CHECK_URL, " 请求头: ", headers)
    if err != OK:
        http.queue_free()
        check_login_failed.emit()

func _on_check_completed(_result, response_code, _headers, body, http_node) -> void:
    http_node.queue_free()
    if response_code != 200:
        check_login_failed.emit()
        return
    var json = JSON.parse_string(body.get_string_from_utf8())
    if typeof(json) == TYPE_DICTIONARY and int(json.get("code", 0)) == 200:
        check_login_success.emit()
    else:
        check_login_failed.emit()

# ---------- 账号密码登录 ----------
func login(username: String, password: String) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_login_completed.bind(http))
    var headers := ["Content-Type: application/json"]
    var body := JSON.stringify({"username": username, "password": password})
    var err := http.request(LOGIN_URL, headers, HTTPClient.METHOD_POST, body)
    print("login response ..........")
    print(err, OK)
    if err != OK:
        http.queue_free()
        login_failed.emit("请求发送失败，请检查网络")

func _on_login_completed(_result, _response_code, _headers, body, http_node) -> void:
    http_node.queue_free()
    var json = JSON.parse_string(body.get_string_from_utf8())
    print("checking loging......")
    print(json)
    if typeof(json) != TYPE_DICTIONARY:
        login_failed.emit("服务器返回数据异常")
        return
    if int(json.get("code", 0)) == 200:
        print("yes login done...")
        _save_token(str(json.get("token", "")))
        login_success.emit()
    else:
        login_failed.emit(str(json.get("msg", "登录失败")))

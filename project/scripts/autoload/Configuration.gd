extends Node

const RES_CONFIG_PATH := "res://configuration.ini"
const USER_CONFIG_PATH := "user://configuration.ini"

var _res_config := ConfigFile.new()
var _user_config := ConfigFile.new()


func _ready() -> void:
    print("Configuration.gd _ready() called.")
    _load_or_init_res_config()
    _load_or_init_user_config()


func _load_or_init_res_config() -> void:
    var err := _res_config.load(RES_CONFIG_PATH)
    if err != OK:
        push_warning("无法加载 RES_CONFIG_PATH 文件: %s (err=%d)" % [RES_CONFIG_PATH, err])
    # --- 排查专用：打印 INI 文件里实际解析到的所有 Section 和 Key ---
    # print("================ INI 实际解析内容 ================")
    # print("解析到的所有 Section: ", _res_config.get_sections())
    # for sec in _res_config.get_sections():
    #     print("Section [%s] 包含的 Keys: %s" % [sec, _res_config.get_section_keys(sec)])
    #     for k in _res_config.get_section_keys(sec):
    #         print("  -> %s = %s" % [k, _res_config.get_value(sec, k)])
    # print("==================================================")


func _load_or_init_user_config() -> void:
    var err := _user_config.load(USER_CONFIG_PATH)
    if err != OK:
        # 第一次运行，创建默认配置
        _user_config.set_value("APP", "app_version_name", "0.0.0")
        _user_config.set_value("APP", "app_version_code", 0)
        _user_config.set_value("APP", "last_pck_vname", "0.0.0")
        _user_config.set_value("APP", "last_pck_vcode", 0)
        _user_config.set_value("APP", "client_uuid", _generate_uuid())

        _user_config.set_value("USER", "language", "zh_CN")
        _user_config.save(USER_CONFIG_PATH)
        return

    # 老版本没有 clientuuid 的情况下补上
    var clientuuid: String = _user_config.get_value("APP", "client_uuid", "")
    if clientuuid.is_empty():
        _user_config.set_value("APP", "client_uuid", _generate_uuid())
        _user_config.save(USER_CONFIG_PATH)

func getResValue(section: String, key: String, default = null) -> Variant:
    return _res_config.get_value(section, key, default)


func getUserValue(section: String, key: String, default = null) -> Variant:
    return _user_config.get_value(section, key, default)


func setUserValue(section: String, key: String, value: Variant) -> void:
    _user_config.set_value(section, key, value)
    _user_config.save(USER_CONFIG_PATH)


func _generate_uuid() -> String:
    var bytes := PackedByteArray()
    bytes.resize(16)

    for i in range(16):
        bytes[i] = randi() % 256

    # UUID v4
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80

    var hex := bytes.hex_encode()

    return "%s-%s-%s-%s-%s" % [
        hex.substr(0, 8),
        hex.substr(8, 4),
        hex.substr(12, 4),
        hex.substr(16, 4),
        hex.substr(20, 12)
    ]

extends Node

const CONFIG_PATH := "user://configuration.ini"

var _config := ConfigFile.new()


func _ready() -> void:
    _load_or_init_config()


func _load_or_init_config() -> void:
    var err := _config.load(CONFIG_PATH)

    if err != OK:
        # 第一次运行，创建默认配置
        _config.set_value("APP", "app_version_name", "0.0.0")
        _config.set_value("APP", "app_version_code", 0)
        _config.set_value("APP", "pck_version_name", "0.0.0")
        _config.set_value("APP", "pck_version_code", 0)
        _config.set_value("APP", "client_uuid", _generate_uuid())

        _config.set_value("USER", "language", "zh_CN")


        _config.save(CONFIG_PATH)
        return

    # 老版本没有 clientuuid 的情况下补上
    var clientuuid: String = _config.get_value("APP", "client_uuid", "")
    if clientuuid.is_empty():
        _config.set_value("APP", "client_uuid", _generate_uuid())
        _config.save(CONFIG_PATH)


func get_val(section: String, key: String, default = null) -> Variant:
    return _config.get_value(section, key, default)


func set_val(section: String, key: String, value: Variant) -> void:
    _config.set_value(section, key, value)
    _config.save(CONFIG_PATH)


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
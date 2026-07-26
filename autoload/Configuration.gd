extends Node

# 配置文件保存路径（使用 user:// 以确保导出后具备读写权限）
const CONFIG_PATH: String = "user://configuration.ini"
const SECTION_NAME: String = "App"

# ConfigFile 实例
var _config: ConfigFile = ConfigFile.new()

func _ready() -> void:
    _load_or_init_config()

## 初始化并加载配置，保证 clientuuid 始终存在
func _load_or_init_config() -> void:
    _config.load(CONFIG_PATH)
    
    # 检查 clientuuid 是否存在，不存在则初始化 UUID 并写入文件
    var clientuuid: String = _config.get_value(SECTION_NAME, "clientuuid", "")
    if clientuuid.is_empty():
        clientuuid = _generate_uuid()
        _config.set_value(SECTION_NAME, "clientuuid", clientuuid)
        _config.save(CONFIG_PATH)

## 读取配置（找不到则返回指定的 default 默认值）
func get_val(key: String, default = null) -> Variant:
    return _config.get_value(SECTION_NAME, key, default)

## 设置配置项并自动持久化写入 ini 文件
func set_val(key: String, value: Variant) -> void:
    _config.set_value(SECTION_NAME, key, value)
    _config.save(CONFIG_PATH)

## 生成标准 UUID v4 字符串 (兼容 Godot 4)
func _generate_uuid() -> String:
    # 生成 16 字节随机数
    var bytes := PackedByteArray()
    bytes.resize(16)
    for i in range(16):
        bytes[i] = randi() % 256
    
    # 设置 UUID v4 版本位 (Version 4 & Variant 1)
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    
    # 转换成 16 进制字符串 (Godot 4 中使用 bytes.hex_encode())
    var hex := bytes.hex_encode()
    
    return "%s-%s-%s-%s-%s" % [
        hex.substr(0, 8),
        hex.substr(8, 4),
        hex.substr(12, 4),
        hex.substr(16, 4),
        hex.substr(20, 12)
    ]
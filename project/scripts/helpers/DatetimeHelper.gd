class_name DatetimeHelper
extends RefCounted

## ==================== 获取当前时间 ====================

## 获取当前时间戳（秒）
static func now() -> int:
    return int(Time.get_unix_time_from_system())


## 获取当前时间字典
## 返回格式：{year, month, day, weekday, hour, minute, second, dst}
static func now_dict() -> Dictionary:
    return Time.get_datetime_dict_from_system()


## 获取当前格式化时间字符串
## format 支持：YYYY, MM, DD, HH, mm, ss
## 示例：format_now("YYYY-MM-DD HH:mm:ss") → "2026-08-02 19:30:00"
static func format_now(format: String = "YYYY-MM-DD HH:mm:ss") -> String:
    return format_timestamp(now(), format)


## ==================== 时间戳 ↔ 字典 / 字符串 ====================

## 时间戳转字典
static func timestamp_to_dict(timestamp: int) -> Dictionary:
    return Time.get_datetime_dict_from_unix_time(timestamp)


## 字典转时间戳
static func dict_to_timestamp(dict: Dictionary) -> int:
    return int(Time.get_unix_time_from_datetime_dict(dict))


## 时间戳格式化
## 支持占位符：YYYY MM DD HH mm ss
static func format_timestamp(timestamp: int, format: String = "YYYY-MM-DD HH:mm:ss") -> String:
    var d := timestamp_to_dict(timestamp)
    var result := format
    result = result.replace("YYYY", "%04d" % d.year)
    result = result.replace("MM", "%02d" % d.month)
    result = result.replace("DD", "%02d" % d.day)
    result = result.replace("HH", "%02d" % d.hour)
    result = result.replace("mm", "%02d" % d.minute)
    result = result.replace("ss", "%02d" % d.second)
    return result


## 从字符串解析时间戳（简单版，要求格式 YYYY-MM-DD 或 YYYY-MM-DD HH:mm:ss）
static func parse(text: String) -> int:
    var parts := text.strip_edges().split(" ")
    var date_parts := parts[0].split("-")
    
    if date_parts.size() < 3:
        push_error("DatetimeHelper.parse: 无效日期格式 → " + text)
        return 0
    
    var dict := {
        "year": int(date_parts[0]),
        "month": int(date_parts[1]),
        "day": int(date_parts[2]),
        "hour": 0,
        "minute": 0,
        "second": 0
    }
    
    if parts.size() >= 2:
        var time_parts := parts[1].split(":")
        if time_parts.size() >= 1:
            dict.hour = int(time_parts[0])
        if time_parts.size() >= 2:
            dict.minute = int(time_parts[1])
        if time_parts.size() >= 3:
            dict.second = int(time_parts[2])
    
    return dict_to_timestamp(dict)


## ==================== 时间计算 ====================

## 增加天数
static func add_days(timestamp: int, days: int) -> int:
    return timestamp + days * 86400


## 增加小时
static func add_hours(timestamp: int, hours: int) -> int:
    return timestamp + hours * 3600


## 增加分钟
static func add_minutes(timestamp: int, minutes: int) -> int:
    return timestamp + minutes * 60


## 计算两个时间戳相差的天数（向下取整）
static func diff_days(from_ts: int, to_ts: int) -> int:
    return int((to_ts - from_ts) / 86400.0)


## 计算两个时间戳相差的小时数
static func diff_hours(from_ts: int, to_ts: int) -> int:
    return int((to_ts - from_ts) / 3600.0)


## ==================== 便捷判断 ====================

## 是否是同一天
static func is_same_day(ts1: int, ts2: int) -> bool:
    var d1 := timestamp_to_dict(ts1)
    var d2 := timestamp_to_dict(ts2)
    return d1.year == d2.year and d1.month == d2.month and d1.day == d2.day


## 是否是今天
static func is_today(timestamp: int) -> bool:
    return is_same_day(timestamp, now())


## 获取星期几（0=周日, 1=周一 ... 6=周六）
static func get_weekday(timestamp: int) -> int:
    return timestamp_to_dict(timestamp).weekday


## 获取中文星期
static func get_weekday_cn(timestamp: int) -> String:
    var names := ["日", "一", "二", "三", "四", "五", "六"]
    return "星期" + names[get_weekday(timestamp)]


## 获取当天的开始时间戳（00:00:00）
static func start_of_day(timestamp: int) -> int:
    var d := timestamp_to_dict(timestamp)
    d.hour = 0
    d.minute = 0
    d.second = 0
    return dict_to_timestamp(d)


## 获取当天的结束时间戳（23:59:59）
static func end_of_day(timestamp: int) -> int:
    var d := timestamp_to_dict(timestamp)
    d.hour = 23
    d.minute = 59
    d.second = 59
    return dict_to_timestamp(d)


## ==================== 游戏常用辅助 ====================
## 秒数转可读时间（例如 3661 → "1小时1分钟1秒"）
static func seconds_to_readable(seconds: int) -> String:
    if seconds < 0:
        seconds = 0
    var h := int(seconds / 3600.0)
    var m := int((seconds % 3600) / 60.0)
    var s := seconds % 60
    
    var parts: PackedStringArray = []
    if h > 0:
        parts.append("%d小时" % h)
    if m > 0:
        parts.append("%d分钟" % m)
    if s > 0 or parts.is_empty():
        parts.append("%d秒" % s)
    return "".join(parts)


## 秒数转倒计时格式（HH:mm:ss 或 mm:ss）
static func seconds_to_countdown(seconds: int, show_hours := true) -> String:
    if seconds < 0:
        seconds = 0
    var h := int(seconds / 3600.0)
    var m := int((seconds % 3600) / 60.0)
    var s := seconds % 60
    
    if show_hours or h > 0:
        return "%02d:%02d:%02d" % [h, m, s]
    return "%02d:%02d" % [m, s]
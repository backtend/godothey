class_name WelcomeLogic
extends RefCounted

# const DEVICE_TYPE := "android"


# 初始化
static func initial() -> String:
    var res: Array = await HttpBinLib.doPost("/index/index/initial", {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": ProjectSettings.get_setting("application/config/version", ""),
        "client_uuid": str(Configuration.get_val("clientuuid")),
        "gray_target": "x123123"
    })
    var _code: int = res[0]; var _msg: String = res[1]; var _data: Dictionary = res[2]
    
    if _code != 200:
        print("初始化请求发起失败: %s" % _msg)
        return "res://scenes/home/Home.tscn"

    print("初始化JSON解析成功: %s" % _data)

    # 是否需要升级
    if _data.get("goto_upgrade", false):
        print("需要升级，即将前往升级中心")
        return "res://scenes/upgrade/Upgrade.tscn"
        
    # 是否登录状态 
    if _data.get("current_login", false):
        print("用户已登录，跳转到主界面")
        return "res://scenes/home/Home.tscn"
        
    print("用户未登录，跳转到登录界面")
    return "res://scenes/auth/Login.tscn"

class_name WelcomeLogic
extends RefCounted

# const DEVICE_TYPE := "android"


# 初始化
static func initial() -> String:
    var res: Array = await HttpBinLib.doPost("/index/index/initial", {
        "project_tag": "godothey",
        "device_type": "android",
        "version_name": ProjectSettings.get_setting("application/config/version", ""),
        "client_uuid": str(Configuration.getUserValue("APP", "client_uuid")),
        "gray_target": "x123123"
    })
    var _code: int = res[0]; var _msg: String = res[1]; var _data: Dictionary = res[2]
    
    if _code != 200:
        print("初始化请求发起失败直接进入首页: %s" % _msg)
        return "res://scenes/home/Home.tscn"

    print("初始化JSON解析成功的1: %s" % _data)

    # 是否需要升级程序包
    if _data.get("goto_scene", 'home_scene') == "checking_upgrade":
        print("即将前往升级软体程序")
        return "res://scenes/checking/Upgrade.tscn"
        
    # 是否需要更新资源包
    if _data.get("goto_scene", 'home_scene') == "checking_update":
    # if _data.get("goto_scene", 'home_scene') == "checking_update" and not EnvedLib.editor():
        print("即将前往升级资料片")
        return "res://scenes/checking/Update.tscn"
        
    print("用户未登录，跳转到登录界面")
    return "res://scenes/auth/Login.tscn"

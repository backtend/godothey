extends Node
## 注册为 AutoLoad,并拖到 AutoLoad 列表最顶端(顺序很重要)。
## AutoLoad 在主场景(Main.tscn)加载之前就会初始化,
## 所以在这里挂载本地 pck,能让入口场景第一次加载时就读到新资源。

# const PCK_DIR := "user://update_pcks/"
# const MANIFEST_PATH := "user://update_manifest.json"


func _ready() -> void:
    print("Startup.gd _ready()")
    # _apply_local_pcks()


# func _apply_local_pcks() -> void:
#     # push_error("尝试加载本地资源包!!!!!!!!1111111")
#     # push_warning("尝试加载本地资源包!!!!!!!!22222222")
#     print("尝试加载本地资源包...")
#     if not FileAccess.file_exists(MANIFEST_PATH):
#         push_warning("更新清单文件不存在,无法加载本地资源包")
#         return
#     var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
#     if f == null:
#         push_warning("无法打开更新清单文件,无法加载本地资源包")
#         return
#     var parsed = JSON.parse_string(f.get_as_text())
#     f.close()

#     if typeof(parsed) != TYPE_DICTIONARY:
#         push_warning("更新清单文件格式错误,无法加载本地资源包")
#         return
    
#     for entry in parsed.get("applied", []):
#         var pck_name: String = entry.get("pck_name", "")
#         if pck_name == "":
#             continue
#         var path := PCK_DIR + pck_name
#         if FileAccess.file_exists(path):
#             if not ProjectSettings.load_resource_pack(path, true):
#                 push_warning("加载本地资源包失败: %s" % path)
#         else:
#             push_warning("本地资源包缺失,可能需要重新下载: %s" % path)
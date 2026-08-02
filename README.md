## HELLO GODOT

正确的godot-tools路径是：/Applications/Godot.app/Contents/MacOS/Godot


## 产生签名
keytool -genkeypair \
-alias godothey \
-keyalg RSA \
-keysize 2048 \
-validity 10000 \
-keystore godothey.keystore
证书密码：187-x2

keytool -list -v -keystore godothey.keystore



# 自动升级 RSA签名
```
<!-- # 生成RSA私钥（2048位，密码可选，这里设置为空密码，方便脚本调用）生成的私钥文件：private_key.pem -->
openssl genrsa -out private_key.pem 2048

<!-- # 从私钥导出公钥（供客户端验签使用）生成的公钥文件：public_key.pem -->
openssl rsa -in private_key.pem -pubout -out public_key.pem

私钥用来签名，记得一定要把公钥放在这个文件变量中！！！！ app/src/main/java/com/yongit/box/service/UpgradeService.kt
```




### 打包命令
godot --headless --export-debug "AndroidHello" docs/releases/godothey.apk
godot --headless --export-release "AndroidHello" docs/releases/godothey.apk


## 更改外部编辑器
系统菜单-编辑器设置-搜索“text_editor”
设置可执行文件路径为： /Applications/Visual Studio Code.app
执行参数为： {project} --goto {file}:{line}:{col}
勾选使用外部编辑器

## VSCODE 操作
打开 终端，输入： code --version
如果提示找不到命令，请按以下方式添加：
打开 VS Code。
按 Cmd + Shift + P，输入并选择：textShell Command: Install 'code' command in PATH
重新打开终端，再次输入 code --version 确认。

Godot Tools 的发布者（作者）是：Geequlim
VS Code 市场扩展 ID：geequlim.godot-tools
安装完 Godot Tools 后，按 Cmd + , 打开设置，搜索 godot：
找到 Godot Tools: Editor Path
填入你的 Godot 可执行文件路径，例如(仅工作区)： /Applications/Godot.app/Contents/MacOS/Godot




### 常用函数

_ready()                节点和子节点全部加载完成后执行一次；初始化变量、获取节点、连接信号、设置初始状态
_enter_tree()           节点进入场景树时执行（比_ready更早）；注册管理器、提前初始化
_exit_tree()            节点离开场景树时执行；保存数据、断开信号、释放资源
_process(delta)         每帧执行；角色移动、动画、计时器、摄像机跟随（移动要乘delta保证快慢统一），参数是两次执行的时间差（单位秒）
_physics_process(delta) 固定频率执行（默认60次/秒）；重力、碰撞、move_and_slide()
_draw()                 自定义绘图；画线、圆形、调试图形、血条，需要queue_redraw()重绘
_input(event)           接收所有输入事件；按键按下、鼠标点击、触摸事件，专门接收按键、鼠标点击事件，区分按下瞬间和持续按住
_unhandled_input(event) 处理未被UI消费的输入；ESC菜单、全局快捷键
_notification(what)     接收系统通知；窗口切换、暂停、获得焦点等
_get_configuration_warnings() 编辑器警告提示；给自定义节点显示配置错误信息

Input.is_action_pressed()       按住检测；持续移动、持续开火
Input.is_action_just_pressed()  刚按下1帧；跳跃、确认
Input.is_action_just_released() 刚松开1帧；蓄力结束、释放技能
get_node() / $                 获取节点引用
add_child()                    动态添加节点
queue_free()                   删除节点（下一帧安全销毁）
instantiate()                  从PackedScene创建实例
preload()                      编译时预加载资源
load()                         运行时加载资源
await                           等待信号或协程
emit_signal()                  发送信号
connect()                      连接信号






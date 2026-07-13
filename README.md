## HELLO GODOT

keytool -genkeypair \
-alias godothey \
-keyalg RSA \
-keysize 2048 \
-validity 10000 \
-keystore godothey.keystore
187-x2

keytool -list -v -keystore godothey.keystore


godot --headless --export-debug "AndroidHello" docs/releases/godothey.apk
godot --headless --export-release "AndroidHello" docs/releases/godothey.apk



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


正确的godot-tools路径是：/Applications/Godot.app/Contents/MacOS/Godot
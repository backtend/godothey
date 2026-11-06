# 启动、登录和发布链路

## 默认启动流程

```text
Bootstrap（APK 中的稳定引导层）
  → 每次冷启动按版本顺序挂载 manifest 中的 PCK
  → Welcome 调 /index/index/initial
  → 按服务端 goto_scene 进入 APK 升级 / PCK 更新 / 登录
  → Login：账号登录或“以游客身份进入游戏”
  → Home：村庄，可进入野外
```

初始化或升级检查请求失败时也先进入 Login，保留游客入口，不直接跳过登录。
游戏内菜单可返回登录页，原 Authy、登录表单、升级场景和接口均保留。
编辑器 F5 会执行线上版本检查，但沿用原行为跳过本地 PCK 挂载；F6 可单独调试游戏场景。

## 两个发布脚本

使用仓库已有 `.venv`，依赖为 requests、OpenSSL、Godot 4.6.3 导出模板和已有 Android SDK/签名配置。

```sh
.venv/bin/python bb_program_and_push.py
.venv/bin/python bb_package_and_push.py
```

上面两条是**真实发布命令**，会上传 OSS 并登记线上版本。

- `bb_program_and_push.py`：生成 APP/PCK 基线版本，写 configuration.ini，导出签名 APK，压缩 ZIP，
  计算哈希与 RSA 签名，检查版本，上传 ZIP/APK，调用 `/zzmdt/builded/uploadapp`。
- `bb_package_and_push.py`：导出 PCK，计算哈希与 RSA 签名，检查版本，上传 PCK，
  调用 `/zzmdt/builded/uploadpck`。不更新 APK 的程序版本，也不改 APK 的资源基线。
- 当前 `AndroidHello` 使用 `all_resources`，因此 PCK 是全量游戏资源包，而非二进制差异包；
  它仍然可以在不重装 APK 的情况下更新场景、游戏脚本和图片。
- APK 构建时临时包含 configuration.ini；资源包不覆盖这份 APK 基线配置。
- 中文字体和 Sprout Lands 授权文本会打包，测试脚本不进入 Android 发布包。

脚本本次仅修复已验证的问题：两个 httppost 合并自定义 headers 时原先返回 None；
APK 脚本在登记版本失败时原先没有以失败状态退出。上传协议、字段、版本规则与签名密钥未改。
两个脚本当前都使用 private_key.pem，与 public_key.pem 配对；没有切换到另一组 pck_* 密钥。

## 补丁生效顺序

`last_pck_vcode` 表示有效版本，不能用来跳过下次进程启动时的挂载。
每次冷启动都要重新挂载高于 APK 内置基线的补丁。

下载写入 `.part` → SHA-256 校验 → 改名为正式 `.pck` → 验证可挂载 → 原子保存 manifest → 重启。
已应用但文件缺失或哈希错误的补丁会重新下载。重复更新不会写入重复版本记录。
更新完成后的版本从实际 manifest 取值，不依赖接口未提供的 `latest_version_code` 字段。
桌面沿用自动重启，Android 沿用提示用户重新打开应用。

游戏会话由 `GameRuntime.gd` 在 PCK 挂载后创建，不注册为 APK Autoload。
这样新游戏脚本及跨场景会话逻辑都可随 PCK 更新，也兼容原 APK 没有新 Autoload 的情况。

**本次修复涉及 Bootstrap 引导层，需要先发布一次新 APK。**
旧 APK 的 Bootstrap 在首次加载主场景时已经被缓存，不能靠该引导层自己随后挂载的 PCK 修复自身。
引导层升级到这版后，后续游戏内容仍走原 PCK 发布流程。
已有 Authy / Configuration Autoload 也属于提前加载层，不应假定它们能随 PCK 在同次启动中替换。

## 验证

```sh
# 6 项 Python 检查：请求头、版本号、INI、签名、公钥配对、上报字段、失败退出
.venv/bin/python -m unittest discover -s tests -p 'test_release_scripts.py' -v

# 隔离存档 + 本机临时服务：启动、更新、游客、强制 APK 提示、补丁下载与第二次冷启动
.venv/bin/python tools/check_release_flow.py

# 游戏交互回归（测试后恢复原游戏存档）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path project --script res://tests/Integration.gd
```

发布链路测试不访问生产发布接口，也不生成线上版本记录。
本次另已实际导出本地 APK/PCK，并挂载导出的 PCK 验证编译后的游戏可初始化。
线上初始化、APK 检查、PCK 检查接口均已只读验证成功；未实际上传新版、发布版本或安装到 Android 真机。

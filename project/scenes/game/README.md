# 青禾物语 · Godot 4.6.3 / GDScript

按 **F5** 从 Bootstrap 启动：挂载本地补丁 → 检查更新 → 登录页 → 点击“以游客身份进入游戏”。
也可打开 `Arena.tscn` 按 F6 直接调试村庄。
`Wild.tscn` 是薄雾林地。世界在运行时构建，编辑器中的空场景是正常的。

## 一条完整玩法路线

1. 找村庄里的巡林员阿远，靠近后按 E / 点交谈，逐句聊完接取委托。
2. 按 Q / 顶部工具按钮换工具，靠近资源按 F / 底部工具按钮采集。
3. 斧头砍树、镐子挖矿各需两次；镰刀采草药一次。资源30秒恢复。
4. 收集木材3、矿石2、草药2，回阿远处交付，获得50金币和2瓶药水。
5. 找药师小禾可用2草药炼制1瓶药水；阿远以10金币出售药水。
6. 东侧发光路口通往野外；野外西侧路口返回村庄，切换有淡入淡出。
7. 野外有三个史莱姆，会追击、攻击。击败得5金币，倒下会被送回村庄。
8. 宝箱给金币和药水；营火恢复生命。NPC 初次礼物与宝箱不会重复领取。

## 背包与操作模式

B / 右上背包打开 **10列 × 5行，共50格**。每格显示图标和右下角数量；点击后在右侧弹出带大图标的详细介绍。

- 食品、能量物品：**食用**，补充生命 / 体力；满状态不消耗。
- 药品：**治疗**，恢复生命；满血不消耗。
- 衣服与工具：**装备**，不消耗物品。青禾旅衣减伤3点；工具用于对应劳动。
- 右下 **丢弃**：选择数量，再次确认后销毁；取消不会扣物品。销毁已装备物品会同步卸下或切换工具。
- 右下 **整理**：按衣服、工具、药品、食品/能量、材料、货币顺序排列；顺序会保存。

旧的平面数量存档会自动迁移为 version=2 的格子存档，保留原有数量，并一次性补充新工具和示例食物、衣服。
新格式中已经销毁的物品不会在重启后重新出现。

点击治疗技能上方的小圆按钮，或按 **M**，按“交互 → 劳动 → 战斗”循环。

| 模式 | 大按钮 | 一技能 | 二技能 | 三技能 |
| --- | --- | --- | --- | --- |
| 交互 | 交互 E | 赠礼 G | 取消 / 离开 | 空 |
| 劳动 | 使用工具 F | 切换工具 Tab | 收起工具 | 空 |
| 战斗 | 攻击 J | 冲刺 K | 震波 L | 治疗 H |

战斗快捷键只在战斗模式生效；E / G 和 F / Tab 分别对应交互和劳动模式。
WASD / 左下摇杆在三个模式中均可移动。Esc 打开菜单或关闭弹窗。

赠礼需要靠近NPC，打开赠礼背包后选物品并按“赠礼”，扣除1件并保存好感；工具和金币不可赠送。
劳动时每次有效动作消耗4点体力，食品与能量浆果可恢复体力，营火可全部恢复。
斧头、镐子、镰刀分别处理树、矿石、草药；锄头用于田地；鱼竿用于池塘钓鱼点（鱼群5秒恢复）。
收起工具后需切换或重新装备再劳动。

摇杆为浮动式：在左下区域落指时建立新圆心，拖动相对该点移动；
松手、失焦、打开弹窗或窗口变更时立即归零并回到默认位置。手机分别跟踪移动手指与动作手指。

## 代码入口

- `scripts/game/GameSession.gd`：挂载补丁后延迟创建，负责跨场景数据、存档、任务、信号和场景淡入淡出。
- `scripts/game/Arena.gd`：TileSet / TileMapLayer、碰撞、村庄/野外生成和实例装配。
- `scenes/entities/player/scripts/Player.gd`：角色状态机、移动、战斗、受伤和工具。
- `scripts/game/Slime.gd`：敌人状态机与追击、攻击、受伤、死亡奖励。
- `scripts/game/WorldObject.gd`：资源、宝箱、营火、路口、假人的统一交互。
- `scripts/game/Villager.gd`：NPC 实体与标识。
- `scripts/game/AdventureUI.gd`：模式行为、NPC对话、赠礼、交易、任务、菜单与提示。
- `scripts/game/BackpackUI.gd`：50格背包、图标数量、物品详情与动作、销毁确认和整理。
- `scripts/game/Inventory.gd`：物品目录、50格顺序、消费/销毁/整理、原子交易与旧存档迁移。
- `scripts/game/MobileControls.gd`：多点触摸摇杆、战斗按钮与 HUD。
- `assets/handmade/`：基础像素图标与世界素材。
- `assets/ui/icons/`：本次新增的15个动作、食物、衣服与工具SVG，圆形金属按钮框由UI代码绘制。

角色状态：IDLE / MOVE / ATTACK / DASH / TOOL / HURT / UI。
`state_changed`、`health_changed`、`inventory.changed`、`quest_changed`、`tool_changed`、
`notified`、`scene_changing`、`harvested`、`defeated` 用于连接数据、实体和界面。

## 存档与运行

物品保存到 `user://arena_inventory.json`，任务、已领物品、工具、地图和生命保存到
`user://meadow_journey.json`。继续旅程会回到所在地图的安全出生点；资源与敌人重新生成。
标题里的“开始新的旅程”在确认后重置这两个原型存档，不影响原登录配置。

默认入口保持原有 Bootstrap → Welcome → APK/PCK 检查 → Login → Home。
`GameRuntime.gd` 在进入游戏后创建根节点 GameSession，避免 Autoload 提前缓存游戏代码。
标题是游戏内入口，菜单可返回标题或登录页。
Android 导出不再排除中文字体，以便离线显示中文界面。

运行集成检查：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path project --script res://tests/Integration.gd
```

测试覆盖采集、背包、药水、对话、任务奖励、交易、宝箱、碰撞、状态机、多点触摸、
跨场景数据、敌人死亡与倒下回村，并在结束时恢复测试前的存档。

这是可扩展的单机原型。对话使用预设剧情；尚未加入联网、复杂寻路和自由文字聊天。

发布脚本、热更新约束和验证命令见仓库根目录的 `docs/release_pipeline.md`。

背包与模式验证（使用隔离存档，不改玩家数据）：

```sh
.venv/bin/python tools/check_gameplay_ui.py
# 同时打开游戏窗口并保存实际截图：
.venv/bin/python tools/check_gameplay_ui.py --capture-dir /tmp/godothey-ui-preview
```

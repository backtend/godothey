## HELLO GODOT

正确的godot-tools路径是：/Applications/Godot.app/Contents/MacOS/Godot
我的游戏根目录配置在：project/project.godot

Project FarmSim (Godot 4.x / GDScript)

这是一个使用 Godot 4 开发的 2D 像素风农场模拟与 RPG 游戏（类似《星露谷物语》）。
本文档旨在为 AI 编码助手（Codex / Copilot Agent）提供项目架构约束、GDScript 代码规范以及模块划分指南。

1. 技术栈与 Godot 4 开发规范 (Engine & Coding Standards)

引擎版本：Godot 4.x (GDScript 2.0)

代码风格 (Style Guide)：

强类型标注：所有变量、函数参数及返回值必须使用显式类型定义（如 var count: int = 0，func get_item() -> ItemData:）。

命名规范：文件与节点用 Snake_case 或 PascalCase，函数与变量用 snake_case，常量用 UPPER_SNAKE_CASE，信号用 snake_case（动词过去式，如 item_picked_up）。

架构模式 (Architecture Patterns)：

节点组件化 (Node Composition)：尽量使用 Node/Node2D 作为功能组件组合组合功能，而不是深层继承。

信号解耦 (Signal-Driven)：跨模块通信统一使用 Signal 或全局事件总线（EventBus），严禁深层 get_node("../../...") 硬编码引用。

数据驱动 (Resource-Based)：物品、配方、作物生长数据、NPC 属性等必须统一使用自定义 Resource (@export 导出的 .tres 资源文件) 来管理。

2. 推荐的核心 Autoload (全局单例)

EventBus (event_bus.gd)：负责全局广播解耦事件（如 day_changed, player_energy_changed）。

TimeManager (time_manager.gd)：掌控游戏世界时间、昼夜轮转与季节计算。

InventoryManager (inventory_manager.gd)：处理玩家数据存储、背包槽位增删与持久化。

3. 核心功能模块设计 (Core Systems)

A. 时间与天候系统 (Time & Weather System)

时间粒度：控制游戏内的分、时、天、季（春/夏/秋/冬）与年份。

自定义 Resource：通过 DayTime 结构传递时间更新，通过信号触发 TileMapLayer 重绘、作物生长逻辑及 NPC 行为调度。

CanvasModulate：使用环境光节点根据时钟梯度调节昼夜与暗色过滤。

B. 地图网格与作物系统 (Grid & Crop System)

TileMapLayer：使用 Godot 4 的 TileMapLayer 节点划分多层网格（如 Base, TilledDirt, Crops, Objects, Fences）。

GridManager：管理基于 Vector2i 网格坐标的状态（是否已耕地、是否浇水、当前生长的作物引用）。

Crop Resource：包含生长阶段纹理 (Array[Texture2D])、生长天数、收获产出物品等。

C. 玩家与工具系统 (Player & Tools System)

CharacterBody2D：8 方向/4 方向移动，结合 AnimationTree 状态机管理行进、挥工具、钓鱼动画。

RayCast2D / Marker2D：获取当前面向的网格点 Vector2i。

ToolItem Resource：不同的工具枚举（Hoe, WateringCan, Axe, Pickaxe, Scythe），根据当前手中工具触发对应网格交互。

D. 背包与物品数据库 (Inventory & Item System)

ItemData (Resource)：包含 ID、名称、描述、图标 (Texture2D)、可堆叠上限、分类及售价。

InventoryData (Resource)：包含 Array[SlotData]，支持槽位拖拽交换、数量加减、丢弃到场景（实例化 Area2D 掉落物）。

E. NPC 与日程行为树 (NPC & Schedule System)

NavigationAgent2D：NPC 基于 TileMap 寻路移动。

ScheduleResource：基于时间点的目标坐标与行为指令数组（如 08:00 -> Vector2i(10, 15) -> idle）。

DialogueSystem：基于 JSON 或 Resource 的对话树，支持分支选择与好感度门槛。

F. 战斗与随机矿洞 (Mining & Combat System)

Procedural TileMap：基于 FastNoiseLite 程序化生成矿洞地图、矿石分布与刷怪点。

Hurtbox / Hitbox：基于 Area2D 监测打击碰撞，包含击退向量计算与数值伤害提示。

4. 给 Codex 的 Prompt 提示词与指令原则 (Codex Instructions)

当要求 Codex 生成 GDScript 代码时，请明确以下原则：

严格遵守 GDScript 2.0 语法：使用 @export、@onready、signal 等现代语法。

Resource 优先：凡是涉及静态数据（物品属性、作物数据、对话树），先给出继承自 Resource 的 .gd 定义脚本。

节点解耦：代码中不要直接写死绝对路径，通过 @export var node_name: Node 或信号的方式传入。

简洁注释：为关键方法写出简短注释，确保代码清晰易读。

5. 开发路线图 (Roadmap)

[ ] Phase 1: 基础设施 — 时间系统 Autoload + 玩家 CharacterBody2D 移动与动画 + 简单 TileMapLayer

[ ] Phase 2: 农耕 Loop — 网格交互 + Resource 驱动的作物生长系统 + 背包数据 Resource 化

[ ] Phase 3: UI 与交互 — 背包 UI + 快捷栏切换 + 简单商店交易系统

[ ] Phase 4: 世界与 NPC — NPC 寻路与时间调度 + 对话系统

[ ] Phase 5: 矿洞与战斗 — 程序化地图生成 + Hitbox/Hurtbox 战斗系统




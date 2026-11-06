# Sprout Lands · Basic Pack

作者：Cup Nooble。原始授权全文见 [LICENSE.txt](LICENSE.txt)。
本包允许非商业项目使用，要求署名；开源项目应同时保留作者说明和授权条款。
游戏标题和菜单已加入署名。

所有文件已统一为小写 snake_case，修正了原文件中的 charakter / tilset / meterials 等拼写。
`asset_manifest.json` 记录原始文件名、新位置和 SHA-256。
原包中同时提供的空格版和下划线版文件均保留；发生同名时使用 `_variant_2` 区分。
没有重绘或改写原始图片。

- `tilesets/`：草地、水、耕地、墙体、屋顶、门和围栏。
- `objects/`：树木、矿石、植物、宝箱、工具、物品、鸡舍等。
- `characters/`：角色、动作、工具、小鸡和奶牛图集。
- `palette/`：原包配色参考。

`res://scripts/game/SproutArt.gd` 用 Godot AtlasTexture 裁切图集，统一提供地图、场景和背包图标。
村庄中的小鸡与奶牛由 `FarmAnimal.gd` 驱动，支持闲逛和靠近交互。

# Inventory Tags / 库存标签

Project Zomboid Build 42 container-management mod. **Lua only; no Java.**

- **Mod ID:** `InventoryTags`
- **Version:** `0.1.0`
- **Minimum game version:** `42.20.2`
- **Author:** Kinkairy

## 功能 / Features

### 1. 容器分类 / Container Categories

每个具体容器都可以独立选择多个分类。分类采用 **OR** 逻辑：物品命中任意一个已选择分类即可进入。

- 没有选择任何分类 = 不限制，保持原版行为。
- 批量拖入时，符合分类的物品继续转移；不符合的物品留在原处。
- 单件不符合分类的物品同样会被拒绝。
- 保留容器原本的 `AcceptItemFunction`；判断时临时交回原版 `ItemContainer:isItemAllowed()` 执行原限制，再叠加库存标签规则，不会绕过钥匙圈、弹药带等原版限制。
- 当前分类：食物、饮料、医疗、武器、弹药、衣物、工具、材料、书籍、电子设备、车辆零件、农业、捕鱼、烹饪用品、容器、杂物。

Each physical container stores its own multi-select tags. With no tags selected the container remains unrestricted. Existing vanilla acceptance rules remain authoritative.

### 2. 容器排序 / Container Sorting

排序只改变 `ISInventoryPane` 的显示比较器，不重排或移动底层 `ItemContainer` 物品。

支持：

- 默认
- 名称 A-Z / Z-A
- 数量 多-少 / 少-多
- 重量 轻-重 / 重-轻
- 类别 A-Z / Z-A

排序方式按具体容器保存。

### 3. 自动整理 / Auto Organize

自动整理扫描当前容器中可用的原版 **Packing** craft recipes。

- 使用原版 `HandcraftLogic`、`ISEntityUI.HandcraftStart` 和原版 timed action。
- 不自行删除散装物品，也不直接生成包装物品。
- 一次只执行一个可用打包动作；完成后重新扫描，因此可以继续执行“散装 → 盒 → 纸箱”等后续原版打包。
- 只接受输入物品全部来自当前容器的配方，不会借用人物库存或附近其他箱子的材料。
- 先排除 Open / Unpack / Unstack / Unbundle / Unwrap / Remove / Take Out / Empty 等反向配方，再只接受 Pack / Place / Put / Stack 方向，避免误执行 Gather Gunpowder、Take Clay from Sack、Empty Sack 等同属 Packing 分类但不是整理用途的配方。
- 原版生成的包装结果会通过原版库存转移动作送回正在整理的容器。

## 两个原版 UI 入口 / Two native UI entry points

三个功能都会同时出现在：

1. **世界物体右键菜单**（包括放在地上的容器物品）
2. **容器物品本身的原版库存右键菜单**
3. **Loot 容器物品栏底部控制区**

底部控制区直接使用 B42 的 `ISLootWindowContainerControls.AddHandler()` 扩展点，与炉灶/微波炉控制使用同一套原版 `ISButton` / handler 系统。分类和排序弹出项使用原版 `ISContextMenu` 和原版勾选标记。

不创建自定义面板或自绘菜单。

## 沙盒选项 / Sandbox options

三项功能分别独立开关，默认全部开启：

- `InventoryTags.EnableCategories`
- `InventoryTags.EnableSorting`
- `InventoryTags.EnableAutoOrganize`

关闭某项后，它的世界右键入口、容器底部入口和对应运行逻辑都会停用。

## 数据与多人同步 / Persistence and multiplayer

- 世界容器：设置写入对应 `IsoObject` 的 ModData，并按该物体的 container index 分开保存。
- 车辆容器：设置写入对应 `VehiclePart` ModData。
- 物品型容器：设置写入容器物品自身 ModData。
- 世界/车辆容器在 MP 中通过专用 `InventoryTags:setContainerSettings` 命令让服务器恢复权威过滤状态并广播 ModData。
- 物品型容器同时使用原版 item ModData 同步和服务器定位命令；支持人物库存、嵌套背包、世界家具内、车辆储物格内、地上容器及地上容器内的嵌套容器。
- 客户端重连或服务器重启后，第一次重新看到已有设置的容器时会按设置签名自动补同步一次，不每帧重复发送。

## 兼容性原则

- Lua-only。
- 尽量使用事件和 B42 原生扩展点。
- 不替换整个 `ISInventoryPage`、`ISInventoryPane` 或 `ISInventoryPaneContextMenu`。
- 仅对三个转移入口做最小 wrapper：
  - `ISInventoryPane:transferItemsByWeight`
  - `ISInventoryPaneContextMenu.onPutItems`
  - `ISInventoryPaneContextMenu.onMoveItemsTo`
- 原版拖放/转移动作、容量检查、CraftRecipe、HandcraftLogic 和 TimedAction 仍然负责真正的库存变化。

## 测试重点

1. 普通木箱选择“食物 + 饮料”，全选角色库存拖入，只有匹配物品进入。
2. 单独拖入不匹配物品应被拒绝；后续匹配物品不应因前一个无效项而停止。
3. 清除全部标签后恢复原版无限制行为。
4. 钥匙圈/弹药带等原本有限制的容器，在加标签后仍保留原版限制。
5. 世界右键、容器物品库存右键与 Loot 底部的分类勾选状态完全一致。
6. 名称/数量/重量/类别排序切换后不产生实际物品转移。
7. 自动整理只执行 Packing 压缩方向，执行时间、动画、声音和消耗均走原版动作。
8. SP、MP、Dedicated Server 重进存档后分类和排序设置仍保留。
9. 三个沙盒选项分别关闭时，两处对应入口均消失且功能停止。

## Project layout

```text
mods/inventory-tags/
└─ workshop/
   └─ Contents/mods/InventoryTags/
      ├─ mod.info
      ├─ 42.20/mod.info
      └─ common/media/
         ├─ sandbox-options.txt
         └─ lua/
            ├─ shared/InventoryTags/
            ├─ client/InventoryTags/
            └─ server/InventoryTags/
```

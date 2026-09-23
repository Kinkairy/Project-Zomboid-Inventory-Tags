# 按分类选取 / Category-based Select — 0.1.2-SELECT3

## 统一入口

按钮、物品右键、空白列表右键、世界容器右键和手柄菜单均使用同一可用性检查：
选取功能已开启，目标仍在该玩家原生物品栏/拾取栏中显示，且有物品列表。
不使用储物标签白名单，不要求容器设置存放分类。

- 人物、背包、箱柜、车辆货物/座位、尸体、冰箱/冷冻柜/微波炉/洗衣机等功能性容器均可选取。
- 地面注册独立的原生 Floor handler，只增加选取，不增加储物分类、排序或自动打包。
- 所有右键入口为“库存标签 → 选取 → 一级/二级分类”；有其他管理项时选取排第一。
- 两侧普通容器按钮为“选取、分类、排序、自动打包”；不适用的原有功能不会显示。
- 世界右键仅对与点击对象或地面格匹配的当前列表提供选取；不自动打开其他箱子。
- 物品右键按当前列表的直接成员确定来源，兼容没有常规所属容器的地面物品。
- 右键包中包仍选当前来源列表；原有包的管理项保留在以包名标识的子菜单中，不递归选包内物品。

## 一次性操作

点击一级选该组，点击二级只选该原生分类。菜单勾号只随悬停/手柄焦点显示，
点击、移开或关闭后清除；已选物品保持原生多选状态。再次选另一类替换本次选择，
不累积条件，不保存分类勾选。保留“批量 → 全选 / 取消选取”。

只改变当前窗格的 UI 选择，不清除另一侧选择，不搬运、不丢弃、不制作，不写 Store/ModData。
容器切换、关闭/折叠窗口、容器按钮消失或来源不明确时不操作陈旧目标。

## 保持不变

存放标签、分类映射、过滤、排序、自动打包、服务端/网络协议6及所有图片均不改变。
EnableSelection 仍为独立开关，关闭原存放分类不关闭选取。
完全匹配的大堆叠用原生折叠头完整选取；同名混合分类仅选匹配子项。
匹配子项超出原版展开行数的极端混合堆叠仍明确提示，不改全局行数上限。

## Validation boundary

The common predicate applies to standard native inventory/loot lists, not every
third-party replacement inventory UI. A displayed container is not permission to
transfer its contents: any later action remains subject to native rules.
Tests use the actual Selection, Menu, Categories and Controls Lua modules against
explicit UI/Java-list surrogates. They cover routing, source identity, hover ticks,
selection, native stacking conventions and controller retention; no real PZ engine,
Windows UI or multiplayer acceptance is claimed.

Baseline: public 34fdb85a4022abb60922e4a25dfc0b21957cc22a;
private d51d07c09b8509bbfa391c6b77cc28705f4a9412 (preserve concurrent Survivor's Song work).
Native reference: B42.20.2 Lua mirror 8a906692ac56f9d40c078d654eea6c70491cbc62,
ISLootWindowContainerControls.lua, ISLootWindowFloorControlHandler.lua and ISInventoryPane.lua.

```sh
lua tests/selection.lua
python translations/generate.py
python tools/verify_runtime.py
```

The R11 deployment package updates only existing Workshop item 3806178177 with
this pinned runtime, unchanged cover and bilingual description. It does not
upload or clear gallery images/tags, install server runtime, start the game, or
change saves/configuration. Source commits alone are not actual deployment.

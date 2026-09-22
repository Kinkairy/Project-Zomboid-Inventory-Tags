# Category-based selection / 按分类选取 — 0.1.2-SELECT1

## 操作

物品栏/拾取栏增加原生风格“选取 / Select”按钮。
点击“选取 → 一级分组”即选中该组物品；向右进入二级后点击则按原生二级选取。
重开菜单可再勾选另一类，多类取并集；再次点击已勾选项则取消该类。
“选中匹配物品”重用本容器刚才的条件；“批量 → 全选 / 取消选取”分别全选与清空。
每次执行替换本窗格当前选中状态，不清除另一侧物品栏的选择。

条件仅在当前会话的窗格/容器组合中记忆，初始为全不选。
它不读取或改写 Store 分类记录，不复制箱子“允许存放”勾选，不保存至 ModData。
主物品栏也可以选取；所有选择只针对当前显示的列表，不扫描其他箱子或包中包。
收藏、装备不影响“选中”；后续玩家主动发起的转移仍受原版及已有过滤规则约束。

## 原生选中与堆叠

- 写入真实的 `ISInventoryPane.selected` 和对应可见行；不是悬停高亮。
- 执行前刷新当前窗格，按当前对象取行，不使用菜单打开时的陈旧行号。
- 整叠都匹配时折叠选中原生堆叠头，确保超过50件的堆叠仍可被原生右键操作完整解析。
- 同名、不同分类的混合堆叠展开后只选匹配子项，绝不误选整个头。
- 极端混合堆叠的匹配子项落在原版50个展开子项范围之外时，明确提示并不执行新选择；
  不更改原版全局渲染上限，不悄悄选错或漏选后报告成功。
- 手柄菜单支持父项切换和右键/右方向进入二级。手柄原生每帧清空多选的路径仅对本次
  选取做局部保持；移动光标、改变选择、更换/刷新容器或物品移出即放回原版行为。
  这是一次性选择，不是每帧按分类自动选中新到物品。

## Scope

Select changes only UI selection. No take/transfer/drop/craft action is queued.
Container icons, world sprites, capacity, category mapping, storage records,
protocol 6, original packing/filter/server logic, and approved artwork are unchanged.
An independent EnableSelection sandbox option defaults on.
EN/CN/CH rows and generated fallback outputs are updated together.

## Evidence and tests

Baseline: public `307999e5f1ac91002654cc005feaddad6f25eed3`, private
`89ba11b8677ae0c7a99f8f808ec8e531cfc9f236`; baseline runtime
`f16bdda62b516cbf14ff7630866c3e3f0d5565d0`.
Native UI reference: B42.20.2 source mirror commit
`8a906692ac56f9d40c078d654eea6c70491cbc62`, file
`client/ISUI/ISInventoryPane.lua` (blob `86474365bbe51dc31f9cf0d85ecfde3b8272ffa1`).
The reference covers selectIndex, native item flattening, controller update clearing,
refreshContainer grouping, and renderdetails row limits. This is not a claim that
we read the owner's installed 42.20.4 Java/Kahlua runtime.

Run from this repository root:

```sh
lua tests/selection.lua
python translations/generate.py
python tools/verify_runtime.py
```

Tests execute the real new selection, shared classification, menu and controls
modules against explicit surrogate Java lists/native row and controller contracts.
They are offline tests, not PZ engine acceptance, Windows UI testing or multiplayer
certification. No NUC/source deployment or Steam upload is performed by this commit.

The older R8 deployment package remains pinned to LT9; it does not install SELECT1.
The R9.1 media-only package also does not deploy runtime changes. Do not use either
as evidence that this test build is installed or published.

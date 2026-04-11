# 预览页文件类型临时排除 - 已落地实现说明

## 文档定位

本文档基于当前仓库中的真实实现，说明“长按排除文件类型”能力的最终语义、状态边界与测试覆盖。

目标读者：
- 正在实现预览页交互的开发者
- 需要判断改动范围和状态边界的维护者

本文档只覆盖：
- 预览页文件类型 chip 的长按排除交互
- 临时排除如何接入 `PreviewController` 的真实预览构建链路
- 排除状态与当前页面本地列表筛选的协作方式
- 摘要如何跟随当前页面筛选语义
- 最小必要测试

本文档明确不覆盖：
- 缩略图生成
- 搜索框过滤
- 骨架屏恢复
- 大批量恢复确认弹窗
- 预览模块的大规模状态重构

---

## 当前状态

当前仓库已经落地以下行为：

- 长按文件类型 chip 会切换当前预览会话内的临时排除状态
- 被排除的扩展名不会进入当前 `plan`，也不会参与后续执行
- 被排除的扩展名 chip 仍保留在页面中，并以排除态样式展示
- 页面本地文件类型筛选仍只影响列表显示，不直接改写 `plan`
- 顶部摘要会跟随当前页面筛选结果，而不再固定显示全量 `plan.summary`

这意味着当前预览页同时存在两层筛选语义：

- controller 层的排除：影响 `plan` 与执行
- page 层的查看筛选：影响“当前页面看到的列表与摘要”

---

在开始实现前，需要先明确当前预览链路已经是什么样。

### 1. 预览计划不是前端纯列表过滤

`PreviewController` 当前会先拿到源/目标 `ScanSnapshot`，再做过滤，最后调用 `DiffEngine.buildPlan()` 生成 `SyncPlan`。

当前已经存在两类过滤：
- 全局忽略后缀：通过 `ignoredExtensions` 在 `PreviewController` 中先过滤快照
- 单一扩展名过滤：通过 `activeExtension` 对快照再做一次过滤

相关文件：
- `lib/features/preview/state/preview_state.dart`
- `lib/features/preview/state/preview_controller.dart`

这意味着“影响预览结果和执行结果”的正确接入点仍然是 controller，而不是页面列表组件。

### 2. 预览页已经有一套页面本地的显示层扩展名筛选

`PreviewPage` 里有本地状态 `_selectedExtensions`，它通过
`PreviewWorkbenchActions.filterItemsByExtensions()` 只过滤当前展示出来的列表项。

这套逻辑：
- 不会修改 `previewState.plan`
- 不会影响执行同步
- 只影响列表可见项

相关文件：
- `lib/features/preview/presentation/pages/preview_page.dart`
- `lib/features/preview/presentation/widgets/preview_result_list_section.dart`
- `lib/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart`

### 3. 当前扩展名筛选实际上是“两层语义”

当前代码里已经存在两层不同职责的筛选：

- controller 层过滤：
  决定 `previewState.plan` 里到底有什么，也决定执行同步会执行什么

- page 层过滤：
  决定预览页列表当前显示哪些 item

本次功能不建议顺手把这两层完全重构掉。更稳妥的做法是：
- 保留现有页面本地显示层筛选
- 新增一套 controller 层的“临时排除后缀”
- 明确优先级：临时排除高于页面本地显示筛选

### 4. 当前没有对应的缩略图 / 搜索 / 骨架屏链路

预览页当前的列表渲染是文本列表加详情面板，不存在这次功能必须联动的：
- 缩略图管线
- 搜索结果集
- 恢复时懒加载骨架屏

因此这些能力不应写进本次实现范围，否则会把任务从“预览筛选增强”扩成“预览模块功能扩建”。

---

## 目标

本次功能的真实目标应收口为：

1. 用户可以在预览页对某个扩展名 chip 长按，切换该扩展名的临时排除状态。
2. 被临时排除的扩展名不会再进入当前 `previewState.plan`。
3. 被临时排除的扩展名不会参与后续同步执行。
4. 该扩展名 chip 仍然保留在界面上，只是改为排除态样式。
5. 页面本地显示层筛选仍然保留，但不能覆盖临时排除结果。
6. 顶部摘要跟随当前页面筛选，显示“当前视图数量”而不是全量总数。
7. 这套排除状态只属于当前预览会话，不写入设置页全局忽略配置。

---

## 非目标

本次实现不做以下事情：

1. 不把当前页面本地 `_selectedExtensions` 和 `PreviewState.activeExtension` 一次性统一成一套新模型。
2. 不把 `PreviewState.activeExtension` 再扩展成新的交互中心；本次仅保持它在现有刷新链路中的兼容行为。
3. 不改设置页“全局忽略后缀”的行为。
4. 不引入搜索、缩略图、骨架屏、恢复确认弹窗等额外能力。
5. 不重做首页工作台与预览页之间的导航或状态托管方式。

---

## 方案选择

### 选择结果

采用“保留现有页面显示筛选，新增 controller 层临时排除”的最小落地方案。

### 原因

这样做最贴合当前代码：

- `PreviewController` 本来就是生成真实 `SyncPlan` 的地方
- `PreviewPage` 本来就有页面级扩展名多选筛选
- 首页与预览页都共享 `previewControllerProvider`
- 执行后刷新预览时，当前实现会重新调用 `buildLocalPreview()` 或 `buildPreviewFromSnapshots()`

因此最自然的改法是：
- 新增 `excludedExtensions`
- 在 controller 里把它和现有快照过滤链路合并
- 在预览页 UI 上增加长按交互和排除态样式

而不是：
- 继续只在列表组件里做“看起来被排除”
- 或者顺手重写整个扩展名筛选模型

---

## 状态设计

### PreviewState 扩展

在 `PreviewState` 中新增：

```dart
final Set<String> excludedExtensions;
```

语义：
- 仅表示当前预览会话内的临时排除后缀
- 不写入 `settings_store`
- 不替代 `ignoredExtensions`

职责区分：
- `ignoredExtensions`
  表示设置页里已经持久化的全局忽略后缀
- `excludedExtensions`
  表示预览页当前会话内临时排除的后缀

### 当前状态关系

本次改动后，扩展名相关状态会分成三类：

- `ignoredExtensions`
  全局配置，构建预览前就已生效

- `excludedExtensions`
  当前预览会话内临时排除，影响 `plan` 和执行

- `_selectedExtensions`
  预览页页面本地显示层筛选，只影响列表展示

### 优先级

优先级从高到低如下：

1. `ignoredExtensions`
2. `excludedExtensions`
3. `_selectedExtensions`

解释：
- 全局忽略的后缀本来就不应进入当前预览可选项
- 临时排除的后缀虽然仍显示 chip，但不应继续进入 `plan`
- 页面本地多选仅用于“从剩余结果里看哪几类”

---

## 会话边界

### 临时排除属于“当前预览会话”

这里的“当前预览会话”按当前代码应定义为：
- 一次预览构建后得到的当前 `PreviewState`
- 以及基于同一状态继续执行后的自动刷新

### 何时保留

以下场景应保留 `excludedExtensions`：
- 在预览页内继续切换 section
- 执行同步后自动刷新当前预览
- 预览页与首页之间来回切换，但仍复用同一份 `PreviewState`

### 何时重置

以下场景应重置 `excludedExtensions`：
- `PreviewController.clear()`
- 用户主动重新生成一份新的预览
- 源目录或目标快照发生变化，并开始新的预览构建

### 为什么不是“退出预览页就重置”

当前首页和预览页共享同一个 `previewControllerProvider`。如果仅因为路由返回首页就清空临时排除，会让同一份预览在两个页面之间表现不一致，也不符合当前状态托管方式。

因此本次实现不把“离开预览页 route”作为清空条件，而是把“重建预览或清空预览”作为清空条件。

---

## 核心实现

### 1. 在 controller 中统一应用临时排除

需要把当前的快照过滤链路收口为两步：

1. 先应用全局忽略后缀
2. 再应用当前会话临时排除后缀
3. 最后再应用已有的 `activeExtension`

建议新增内部辅助方法，例如：

```dart
ScanSnapshot _applyPlanFilters(
  ScanSnapshot snapshot, {
  required String activeExtension,
  required Set<String> excludedExtensions,
})
```

其职责：
- 从已经过 `ignoredExtensions` 处理的 `baseSource` / `baseTarget` 中再过滤掉 `excludedExtensions`
- 然后保留当前 `activeExtension` 对应结果

这样可以避免：
- 在多个入口重复写过滤逻辑
- `toggleExclude` 和 `buildPreviewFromSnapshots` 行为不一致

这里对 `activeExtension` 的要求是“兼容现状”，不是“继续扩展语义”：

- 当前代码仍保留 `activeExtension` 这层 plan 过滤能力
- 本次功能不新增围绕 `activeExtension` 的页面交互
- 本次新增的主语义只有 `excludedExtensions`
- 后续若要统一筛选模型，应单独开题处理

### 2. 新增 toggleExclude 能力

在 `PreviewController` 中新增：

```dart
void toggleExcludedExtension(String extension)
```

要求：
- `*` 不允许进入排除集合
- 如果 `extension` 已排除，则恢复
- 如果尚未排除，则加入排除集合
- 切换后立即基于当前 `sourceSnapshot` / `targetSnapshot` 重建 `plan`

注意：
- `availableExtensions` 不应因为临时排除而移除该扩展名
- 否则用户将无法看到并恢复该排除项

### 2.1 `loadPlan()` 处理原则

本次功能的核心要求只有一条：

- 排除后，列表中不出现
- 排除后，传输时也不处理

因此真正必须改通的是“生成当前 `plan` 的真实链路”。

对 `loadPlan()` 的处理建议是：

- 如果它在当前实际流程中不会参与重建预览，则本次可以不改
- 如果后续确认它也会重新生成当前 `plan`，再把 `excludedExtensions` 补进去

也就是说，`loadPlan()` 不是本次方案的 blocker，更像实现时的兼容检查项。

### 3. build 入口默认重置临时排除

对“新建预览”的入口，建议默认清空 `excludedExtensions`：

- `buildLocalPreview()`
- `buildPreviewFromSnapshots()`

原因：
- 用户重新生成预览，语义上应开启新的临时探索会话
- 旧会话里的临时排除不应悄悄继承到新预览

### 4. 执行后刷新需要显式保留临时排除

当前执行完成后，`PreviewWorkbenchActions.refreshPreviewAfterExecution()` 会重新构建预览。

这里要特别处理：
- 手动重新生成预览时重置 `excludedExtensions`
- 执行后自动刷新时保留 `excludedExtensions`

因此需要在刷新路径中把当前 `previewState.excludedExtensions` 继续传回 controller。

相关文件：
- `lib/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart`

---

## UI 交互

### 点击行为

点击行为沿用当前页面现状，而不是改成全新的单选模型。

也就是说：
- 普通点击未排除 chip：
  继续使用当前 `_selectedExtensions` 多选逻辑，只影响列表显示

- 点击已排除 chip：
  不执行显示筛选切换
  不额外弹教学型提示

### 长按行为

长按行为是本次新增的真实过滤动作：

1. 长按普通扩展名 chip
2. 触发 `toggleExcludedExtension(extension)`
3. controller 立即重建 `plan`
4. 列表和摘要同步刷新
5. chip 进入排除态

再次长按已排除 chip：

1. 从 `excludedExtensions` 中移除
2. controller 重新构建 `plan`
3. chip 恢复默认态

### 与页面本地多选的协作

当一个扩展名被临时排除时，需要同步修正页面本地 `_selectedExtensions`：

- 如果该扩展名原本在 `_selectedExtensions` 中，则移除
- 若移除后为空，则回退到 `{'*'}` 表示“显示全部剩余结果”

这样可以避免出现：
- 列表本地仍认为自己选中了某扩展名
- 但 controller 层已经把该扩展名从 `plan` 中移除

### 与摘要的协作

当前实现里，顶部摘要不再直接复用全量 `previewState.plan.summary`，而是按当前页面可见结果重新计算。

也就是说：

- 文件类型筛选会影响摘要
- 分组筛选会影响摘要
- `copy bytes` 只统计当前视图里的 copy 项
- conflict 数按当前页面仍可见的冲突项统计

这样可以避免出现“列表看的是局部，摘要显示的还是全量”的语义错位。

### 文案策略

本次交互优先靠状态表达，不靠大量文字解释。

建议原则：

- 主要通过 chip 的排除态样式表达“该类型已被排除”
- 不新增“长按可恢复”之类教学型提示
- 操作成功后只保留极短反馈
- 所有新增文本走 l10n，不写死字符串

建议新增的反馈文案收敛为：

- `已排除 {ext}`
- `已恢复 {ext}`

除这两类结果反馈外，不再额外引入说明性文案。

---

## 视觉设计

### 状态层级

当前 chip 的语义层级应为：

```text
排除态 > 选中态 > 默认态
```

### 样式建议

沿用当前 `FilterChip` 风格，新增排除态：

| 状态 | 背景 | 边框 | 文字 | 图标 |
| --- | --- | --- | --- | --- |
| 默认态 | `surface` 或现有默认 | `outlineVariant` | 默认 | 无 |
| 选中态 | 维持当前 `FilterChip.selected` | 当前选中样式 | 当前选中样式 | 无 |
| 排除态 | `surfaceContainerHighest` | `error` | `error` | `Icons.block` |

建议保留：
- 红色描边
- 红色文字
- 禁止图标

建议不做：
- 大面积危险色填充
- 与删除态视觉太接近的强调样式

### 长按反馈

本次可以保留轻量反馈，不要把交互做得过重，也不要过度依赖文字说明。

推荐：
- `HapticFeedback.mediumImpact()`
- `SnackBar` 仅提示“已排除 .mp3”或“已恢复 .mp3”
- 可选的轻微缩放动画

不建议首版加入：
- 半透明覆盖层
- 复杂进度预告动画
- “长按可恢复”之类教学型提示

---

## 文件级实现

### `lib/features/preview/state/preview_state.dart`

新增：
- `excludedExtensions`

更新：
- `initial()` 默认值

### `lib/features/preview/state/preview_controller.dart`

新增或调整：
- `toggleExcludedExtension()`
- 统一过滤辅助方法
- 新预览构建时重置排除
- 自动刷新时允许保留排除

### `lib/features/preview/presentation/pages/preview_page.dart`

当前实现已包含：
- 监听长按事件
- 点击已排除项时不切换本地显示筛选
- 长按切换排除后同步修正 `_selectedExtensions`
- `SnackBar` 反馈
- 顶部摘要按当前页面筛选结果重算

### `lib/features/preview/presentation/widgets/preview_result_list_section.dart`

当前实现已包含：
- 向 chip 组件传入 `excluded` 状态
- 增加 `onLongPressExtension`
- 为 chip 增加排除态视觉样式
- 为扩展名 chip 提供稳定测试 key，便于 widget 测试定位

### `lib/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart`

当前实现已包含：
- 执行后刷新预览时保留 `excludedExtensions`

### 测试目录

建议新增或更新：
- `test/unit/preview/...`
- `test/widget/...`

---

## 已落地范围

- `PreviewState` 已增加 `excludedExtensions`
- controller 已统一接入临时排除过滤链路
- 已支持 `toggleExcludedExtension()`
- `availableExtensions` 不会因临时排除而消失
- 已明确“新建预览重置排除、执行后刷新保留排除”
- 扩展名 chip 已支持长按排除 / 恢复
- 点击已排除 chip 不会切换本地显示筛选
- 长按切换后会同步修正 `_selectedExtensions`
- 已提供排除态样式、短反馈文案与轻量触觉反馈
- `*` 已被保护，不允许排除
- 顶部摘要已跟随当前页面筛选结果
- 已补 controller 单测与关键 widget 测试

---

## 边界情况

### 1. `*` 不能被排除

原因：
- 它不是实际扩展名
- 只是“显示全部剩余类型”的 UI 语义

### 2. 全局忽略的扩展名不需要显示为可排除 chip

原因：
- 当前 `availableExtensions` 本来就是在全局忽略后统计出来的
- 这类后缀不会进入预览页临时管理范围

### 3. 排除某扩展名后，计划摘要与当前视图摘要都应立即同步变化

因为排除会直接重建 `plan`，同时页面摘要又按当前视图重算，所以：
- 排除后，全量 `plan` 会变化
- 当前页面列表会变化
- 顶部摘要也会跟着当前页面可见结果变化

### 4. 排除所有当前可见扩展名

预期行为：
- 列表进入空态
- 扩展名 chip 仍可见
- 用户可通过再次长按恢复任意扩展名

### 5. 冲突项也必须遵守排除规则

临时排除不只是隐藏 copy/delete 列表项，而是从 `plan` 构建前就被过滤。

因此：
- copy
- delete
- conflict

都必须一并消失。

---

## 测试用例

### controller 单测

1. 排除一个扩展名后，该扩展名相关的 copy/delete/conflict 都不再进入 `plan`
2. 恢复一个扩展名后，该扩展名重新回到 `plan`
3. `availableExtensions` 仍保留被排除的扩展名
4. 全局忽略后缀与临时排除叠加时，结果符合优先级
5. 新建预览时会重置旧的 `excludedExtensions`
6. 执行后刷新当前预览时会保留 `excludedExtensions`

### widget 测试

1. 已排除 chip 显示禁止图标和错误色描边
2. 点击已排除 chip 不切换本地选中状态
3. 长按普通 chip 后触发排除
4. 长按已排除 chip 后触发恢复
5. 排除后若 `_selectedExtensions` 为空，会回退到 `*`
6. 顶部摘要会跟随文件类型筛选结果变化

---

## 实现备注

这份方案有意不在本次顺手清理掉当前“controller 层真实过滤”和“page 层显示过滤”双轨并存的问题。

原因不是这个问题不存在，而是：
- 当前功能的最小闭环是“长按排除影响 plan 与执行”
- 把双轨筛选彻底统一会额外波及首页工作台、预览页列表和执行后刷新语义
- 这会明显扩大任务范围

因此本次建议先做对、做稳、做收敛。

如果后续要继续收口，可以在下一轮单独处理：
- `PreviewState.activeExtension` 是否仍有保留价值
- 页面本地 `_selectedExtensions` 是否应该并入 provider 状态
- 扩展名筛选是否应统一成单一语义模型

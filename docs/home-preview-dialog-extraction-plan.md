# Home 预览工作台弹窗化代码级方案

本文档定义 `HomePage` 将预览工作台提取为独立弹窗的最小可落地方案。目标是：在不改业务语义的前提下，隔离主页面滚动与预览滚动冲突，降低 `home_page.dart` 认知负担，并对齐当前项目规范与 MD3 交互习惯。

## 1. 设计结论

- `HomePage` 仅保留“概览与入口”，不再承载完整预览工作台交互树。
- `PreviewWorkbenchSection` 保持为核心内容组件，不重写内部业务逻辑。
- 通过标准 MD3 弹窗容器承载工作台，内部独立滚动，不与主页面滚动共享控制权。
- 首阶段优先“可回退、低侵入、复用已有组件”，不引入新的状态管理层。

## 2. 范围与文件

首阶段涉及：

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/widgets/home_dialogs/home_dialogs.dart`
- `lib/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart`（仅必要的可选参数扩展）
- 可选新增：`lib/features/home/presentation/widgets/home_dialogs/preview_workbench_dialog.dart`

不在首阶段做：

- 不改 `PreviewWorkbenchActions` 业务语义
- 不改 `RemoteSyncExecutor`、`ConnectionController` 等状态流
- 不顺带改设置页与计划列表已上线的滚动策略

## 3. UI 与 MD3 规范约束

- 弹窗优先复用项目现有通用壳（`AppDialogShell` / 现有 dialog 规范）。
- 标题区遵循 MD3：标题 + 支持性文案（可选）+ 右上角关闭。
- 操作区（底部）保留最小按钮集：
  - `关闭`
  - 可选 `打开结果`（仅当已有结果时展示）
- 弹窗内容区内部自滚动，外层页面不参与滚动。
- 窄窗口采用接近全高弹窗，宽窗口采用中等宽度工作台弹窗。

## 4. 组件拆分方案

### 4.1 Home 页面入口收口

在 `home_page.dart` 中：

- 用 `_openPreviewWorkbenchDialog(...)` 统一打开动作。
- `homeStepPreview` 卡片改为：
  - 概览信息（计划条目数、冲突数、当前状态）
  - 进入按钮（`打开预览工作台`）
- 原先内联的 `PreviewWorkbenchSection` 从主滚动树移除。

### 4.2 新增 PreviewWorkbenchDialog

建议新增独立 widget：

- `PreviewWorkbenchDialog`（或在 `home_dialogs.dart` 中加 `showPreviewWorkbenchDialog`）

职责：

- 承载 `PreviewWorkbenchSection`
- 提供稳定的弹窗尺寸与滚动容器
- 管理关闭动作与必要的底部按钮

### 4.3 复用现有业务组件

- `PreviewWorkbenchSection` 继续复用，参数从 `home_page` 原封传入。
- `PreviewPlanSection`、`PlanItemList` 不改接口，继续在弹窗内部发挥。
- `home_workspace_layout` 继续负责 Home 主页面布局，但不再直接装配大体积预览区。

## 5. 实施步骤

1. 在 `home_dialogs` 增加 `showPreviewWorkbenchDialog(...)` 入口。
2. 新建/接入 `PreviewWorkbenchDialog`，复用现有 dialog 壳与风格。
3. 将 `home_page` 中预览卡片替换为“摘要 + 打开弹窗”入口。
4. 将原先构造 `PreviewWorkbenchSection` 的参数拼装收口到一个 builder 方法，避免散落。
5. 为弹窗内容加独立滚动层（仅弹窗内部生效）。
6. 做最小验证：`dart format` + `flutter analyze` + 人工滚动验证。

## 6. 风险与回退

已知风险：

- 弹窗内高度管理不当会导致内容裁剪或多层滚动。
- 入口摘要与弹窗内容状态若不同步，容易产生“表里不一”。

回退策略：

- 保留 `PreviewWorkbenchSection` 原接口不变。
- 若弹窗方案异常，可快速回退为“主页内嵌预览区”，不影响执行链路。

## 7. 验证清单

- Home 主页面滚动条长度在滚动过程中不再明显波动。
- 在预览列表内滚轮滚动时，主页面不再联动跳动。
- 窄窗口（矮高度）下弹窗内容可完整访问。
- 远程构建预览、执行同步、取消、打开结果等动作语义不变。
- `flutter analyze` 无新增错误。


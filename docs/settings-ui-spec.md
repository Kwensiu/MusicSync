# Settings 页面样式规范（当前实现）

本文档基于当前代码实现，定义 Settings 页的结构、样式约束和扩展方式。目标是：后续新增设置项时，不破坏现有视觉与交互一致性。

## 1. 适用范围

- 页面入口：`lib/features/settings/presentation/pages/settings_page.dart`
- 分组与行组件：`lib/features/settings/presentation/widgets/settings_group.dart`
- 通用弹窗壳：`lib/features/settings/presentation/widgets/settings_dialog_shell.dart`
- 通用选项弹窗：`lib/features/settings/presentation/widgets/settings_choice_dialog.dart`
- 业务弹窗：
  - `ignored_file_types_dialog.dart`
  - `theme_mode_dialog.dart`
  - `palette_dialog.dart`

## 2. 页面结构规范

Settings 页面采用单列 `ListView`，固定结构如下：

1. 顶部标题行  
   左侧返回圆按钮 + 右侧大标题“设置”
2. 分组标题：`常规`
3. Joined Group（卡片组 1）  
   - 自动监听（Switch）
   - 忽略文件类型（进入管理弹窗）
4. 分组标题：`外观`
5. Joined Group（卡片组 2）  
   - 主题模式（进入选择弹窗）
   - 调色板（进入选择弹窗）

说明：分组标题与卡片组之间使用小间距，组与组之间使用中间距，保持“清晰分段但不松散”。

## 3. 尺度与圆角（当前 token）

定义位置：`settings_group.dart` 中 `SettingsUiScale`。

- `radiusGroup = 20`
- `rowHorizontal = 16`
- `rowVertical = 16`
- `rowMinHeight = 60`
- `iconSize = 24`
- `iconToText = 16`
- `trailingGap = 8`
- `trailingSlotHeight = 32`
- `dividerStart = 20`
- `dividerEnd = 20`

约束：

- Settings 相关容器优先复用上述 token，避免新增“魔法数字”。
- 目前 `radiusGroup=20` 仅作为 Settings 组卡片标准圆角，不强制覆盖全应用。

## 4. 色彩与材质规范（Material 3）

页面与卡片使用语义色，不写硬编码颜色：

- 页面背景：`surfaceContainerLowest`
- 组卡片背景：`surfaceContainerLow`
- 组卡片边框：`outlineVariant`（半透明）
- 行标题：`onSurface`
- 行副标题/图标：`onSurfaceVariant`

说明：主题模式切换（浅色/深色/跟随系统）与调色板切换由全局主题系统驱动，Settings 仅消费状态。

## 5. 行组件规范（SettingsActionRow）

单行布局固定为：

- 左侧图标
- 中间文字（标题+单行副标题）
- 右侧 trailing（统一放入固定高度槽位）

实现要点：

- 副标题固定 `maxLines=1` + `ellipsis`
- 标题/副标题使用 `StrutStyle` 固定行高，减少字体导致的抖动
- trailing 统一进入 `trailingSlotHeight`，减小 `Switch` 与 `Icon` 的视觉高度差

已知现象：

- 部分设备上，`Switch` 行与普通箭头行仍可能存在约 1px 视觉差异，当前接受，不影响交互。

## 6. 弹窗规范

### 6.1 通用弹窗壳（SettingsDialogShell）

用于所有 Settings 弹窗，负责：

- 最大宽高、最小边距约束
- 统一圆角
- 统一 action 按钮尺寸/密度

默认风格：紧凑，不留大面积空白。

### 6.2 选项弹窗（SettingsChoiceDialog）

适用于“互斥选择”：

- 选项行为整行可点击
- 当前选项右侧 `check`
- 当前项轻量高亮（`secondaryContainer`）
- 支持 `saveOnSelect=true`（点选即保存并关闭）

当前业务使用：

- 主题模式：点选即保存
- 调色板：点选即保存

## 7. 新增设置项规范

新增一项时建议按以下顺序：

1. 判断归属分组（`常规` 或 `外观`）
2. 优先用 `SettingsActionRow`，不要单独造 row
3. 交互类型：
   - 即时开关：右侧 `Switch`
   - 进入二级配置：右侧 `chevron` + `onTap`
4. 若需弹窗：
   - 优先复用 `SettingsDialogShell`
   - 互斥选项优先复用 `SettingsChoiceDialog`
5. 文案走 i18n，不允许硬编码

## 8. 当前不做的事项

- 不将 `SettingsUiScale` 立即全局化为全应用 design token
- 不在本轮统一所有页面圆角/间距
- 不为 1px 级视觉差异做高风险重构

以上策略用于保持迭代速度与稳定性平衡。

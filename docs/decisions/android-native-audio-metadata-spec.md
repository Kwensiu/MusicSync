# Android 原生音频元数据解析方案规范

## 1. 目标

本方案的目标是：

- 仅在 Android 端新增 Kotlin 原生音频元数据解析能力
- 优化预览场景下的音频标签读取性能
- Windows 和 macOS 保持现有 Dart 解析逻辑不变
- 不做破坏性重构，不改变现有跨平台数据模型

本方案是对现有 Dart 解析链路的增强，而不是替换。

## 2. 方案边界

本次改动只覆盖以下范围：

- Android 本地文件访问链路上的音频元数据读取
- 预览明细中 `AudioMetadataViewData` 所需字段的读取与映射
- Android 原生优先、Dart 回退的兼容策略

本次改动明确不包含以下内容：

- 不修改 Windows 端文件访问实现
- 不修改 macOS 端文件访问实现
- 不调整现有 UI 结构与交互语义
- 不引入新的跨平台模型
- 不把 Dart 解析器整体替换为原生实现

## 3. 总体设计

总体设计统一为：

- 在现有 Android 文件访问 `MethodChannel` 上新增 `getAudioMetadata(entryId)` 方法
- Android 侧根据现有 `entryId` 解析目标文件，并在 Kotlin 层读取音频标签
- Dart 侧在 `AudioMetadataReader` 中先尝试 Android 原生读取
- 原生读取失败、结果无效或字段不足时，回退到现有 Dart 解析逻辑

设计原则如下：

- Android 增强只影响 Android
- 桌面端行为保持不变
- 现有 Dart 解析器继续作为稳定兜底
- UI 和业务层继续只认 `AudioMetadataViewData`

## 4. 通道设计

沿用现有 Android 文件访问通道，新增方法：

- `getAudioMetadata(entryId)`

输入参数：

- `entryId: String`

返回值：

- `Map<String, String?>`

该方法只负责返回统一字段数据，不承担 UI 拼装或差异判断职责。

## 5. Android 侧实现口径

Android 侧实现统一放在现有 `MainActivity.kt` 的文件访问通道分支中。

处理流程统一为：

1. 接收 Dart 传入的 `entryId`
2. 复用现有 `entryId` 解析逻辑，还原 `treeUri` 与 `documentId`
3. 构造目标文件对应的 `DocumentUri`
4. 使用 Kotlin 原生能力读取音频元数据
5. 将结果整理为固定字段 `Map<String, String?>`
6. 通过 `MethodChannel` 返回给 Dart

Android 原生解析优先使用平台已有元数据能力，例如：

- `MediaMetadataRetriever`

如后续发现特定字段覆盖不足，可在 Android 侧增加必要补充解析，但该补充应限制在当前任务相关模块内，不扩散为大范围解析框架重写。

## 6. 数据协议

Android 与 Dart 之间统一使用以下字段集合：

- `title`
- `artist`
- `album`
- `composer`
- `trackNumber`
- `discNumber`
- `lyrics`

约束如下：

- 字段名固定，不做平台分叉
- 字段值类型统一为 `String?`
- 未读取到值时返回 `null`
- 不引入额外嵌套结构

Dart 侧按同名字段映射到 `AudioMetadataViewData`，确保跨平台模型一致。

## 7. Dart 侧实现口径

Dart 侧统一策略为“Android 原生优先，Dart 保底”。

处理流程统一为：

1. 若当前不是 Android，直接走现有 Dart 解析逻辑
2. 若当前是 Android，先尝试调用 `getAudioMetadata(entryId)`
3. 若原生返回有效结果，则映射为 `AudioMetadataViewData`
4. 若原生调用失败、异常、超时、结果全空，或关键字段缺失，则回退现有 Dart 解析

这里的“关键字段缺失”口径统一为：

- 第一优先关注 `title`、`artist`、`album`
- 对 `composer`、`trackNumber`、`discNumber`、`lyrics` 允许原生缺失，但应保留后续用 Dart 补字段的能力

第一版默认允许以下兜底策略：

- 原生结果全空：直接回退 Dart
- 原生结果只有部分字段：可继续用 Dart 补充缺失字段

不建议第一版采用“只要原生成功就完全覆盖 Dart 结果”的策略。

## 8. 兼容策略

兼容策略统一如下：

- `Android + 原生读取成功且结果有效`：优先使用原生结果
- `Android + 原生异常 / 超时 / 全空 / 关键字段不足`：回退现有 Dart 解析
- `非 Android`：始终保持现有 Dart 解析路径

该策略的核心要求是：

- Windows/macOS 现有路径不变
- Android 新增能力不影响其他平台
- 任一原生异常都不能中断预览主流程

## 9. 收益预期

本方案预期收益统一表述为：

- 减少大块音频数据通过 `MethodChannel` 分段传输的次数
- 减少 base64 编解码带来的额外开销
- 降低批量预览时的内存峰值
- 提升 Android 端音频元数据预览速度
- 在不影响桌面端兼容性的前提下优化 Android 体验

## 10. 风险口径

本方案的主要风险不在接入复杂度，而在不同解析器之间的标签覆盖差异。

重点风险包括：

- `MediaMetadataRetriever` 对不同容器和标签格式的支持不完全一致
- `composer`、`lyrics` 等字段可能比现有 Dart 解析器覆盖更弱
- 个别格式在 Android 原生侧可能只能拿到基础字段

统一风险应对口径为：

- 默认保留现有 Dart 解析器作为兜底
- 不以原生结果无条件替代 Dart 结果
- 若字段缺失明显，优先采用“回退”或“补字段”策略

## 11. 实施步骤

实施步骤统一为：

1. 在 Android `MainActivity.kt` 的文件访问通道上新增 `getAudioMetadata` 分支
2. 新增 Kotlin 元数据解析函数，输入 `entryId`，输出固定字段 map
3. 在 Dart `AudioMetadataReader` 中增加 Android 原生优先尝试
4. 增加日志、异常处理与超时保护
5. 保持现有 Dart 解析逻辑作为回退与补充路径
6. 完成 Android 与现有 Dart 结果的对比回归

## 12. 验证要求

本方案的最小验证要求为：

- `dart analyze`
- 相关单元测试通过
- Android 真机或模拟器上对同一批音频文件进行结果对比

回归验证重点关注以下内容：

- `title`、`artist`、`album` 是否稳定一致
- `composer`、`trackNumber`、`discNumber`、`lyrics` 是否出现明显退化
- 原生失败时是否正确回退到 Dart
- Windows/macOS 是否保持原有行为不变

## 13. 最终口径

本方案的最终统一口径为：

仅在 Android 端新增 Kotlin 原生音频元数据解析作为性能增强路径；Dart 侧采用“Android 原生优先，Dart 回退或补充”的兼容策略；Windows 和 macOS 保持现有逻辑不变；跨平台统一输出 `AudioMetadataViewData`，以最小发布风险换取 Android 端预览性能收益。

## 14. 当前状态（已完成）

当前版本按本规范 V1 范围已完成落地，验收口径如下：

- Android 文件访问通道已接入 `getAudioMetadata(entryId)`
- Dart 侧已按“Android 原生优先，Dart 回退或补充”策略落地
- 跨平台模型保持 `AudioMetadataViewData` 不变
- Windows/macOS 路径保持既有实现，不受本次 Android 增强影响

说明：

- 本节“已完成”仅指本规范定义的 V1 目标与边界，不包含扩展能力项

## 15. 后续优化项（非本期阻塞）

以下优化项用于后续迭代，不作为本次发布阻塞条件：

1. Android `lyrics` 真值解析能力增强  
   当前协议字段已保留 `lyrics`，后续可按格式覆盖情况补充原生读取能力，提升歌词字段命中率。

2. Dart 补读按需触发  
   当前策略允许原生后再做 Dart 补字段；后续可优化为“仅缺失字段时触发补读”，进一步降低 I/O 与 CPU 开销。

3. Android 元数据回归样本与指标  
   建立常见格式（如 MP3/FLAC/M4A/Ogg/APE）与多语言标签样本回归，并增加命中率/回退率/耗时指标，支撑后续优化决策。

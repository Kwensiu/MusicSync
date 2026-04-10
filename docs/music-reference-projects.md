# MusicSync 可借鉴项目清单（标签处理与播放器方向）

> 背景：当前项目已明确借鉴 InstallerX-Revived（UI 设计）与 LocalSend（网络/文件传输）。
> 本文补充“音乐语义相关”的参考项目，重点覆盖 tag 处理、元数据一致性与播放器体验。

## 1. 结论先行（建议优先级）

优先建议按下面顺序借鉴：

1. **Picard + beets + TagLib**
   先把标签一致性和规则体系打稳，再做播放器层体验。
2. **Harmonoid / Strawberry**
   在元数据稳定之后，借鉴播放器交互与库管理表现。
3. **Navidrome**
   当项目进入多端一致视图、库索引或后续服务化阶段时引入。

简短判断：
如果先做播放器细节而标签规则未收口，会放大“显示很好看但信息不一致”的体感问题。

## 2. 可借鉴项目与落地价值

## 2.1 MusicBrainz Picard

- 项目链接：https://github.com/metabrainz/picard
- 官方插件 API 文档：https://picard-docs.musicbrainz.org/en/appendices/plugins_api.html
- 适合借鉴：
  - 字段规范化与映射策略（artist/albumartist/track/disc 等）
  - 同一文件多 tag 源冲突时的优先级决策
  - 可扩展的“处理管线”思路（便于后续规则插件化）
- 对 MusicSync 的直接价值：
  - 为“预览差异”与“同步执行”提供统一标签语义，减少两端显示差异

## 2.2 beets

- 项目链接：https://github.com/beetbox/beets
- 适合借鉴：
  - 导入-校正-重命名的批处理流水线
  - 重复检测、缺轨检查、规则可配置
  - “先标准化再落盘”的流程纪律
- 对 MusicSync 的直接价值：
  - 在同步前做统一校验/修复，降低目录漂移和重复文件问题

## 2.3 TagLib

- 项目链接：https://github.com/taglib/taglib
- 适合借鉴：
  - 多格式标签解析边界 case 处理方式（ID3/APE/Vorbis/MP4）
  - 作为解析正确性的参考对照与测试样本来源
- 对 MusicSync 的直接价值：
  - 当前项目已有多容器元数据读取逻辑，可用 TagLib 行为做交叉验证，补齐极端样本

## 2.4 Harmonoid

- 项目链接：https://github.com/harmonoid/harmonoid
- 适合借鉴：
  - Flutter 跨平台音乐库组织方式
  - 播放页、队列、封面、歌词与状态联动
- 对 MusicSync 的直接价值：
  - 可作为“预览 -> 播放验证 -> 执行同步”体验闭环参考

## 2.5 Strawberry

- 项目链接：https://github.com/strawberrymusicplayer/strawberry
- 适合借鉴：
  - 大型本地音乐库扫描与性能策略
  - 智能列表、歌词与元数据联动
  - 桌面端成熟播放器的交互基线
- 对 MusicSync 的直接价值：
  - 给 Windows 端目标体验提供“上限样板”

## 2.6 Navidrome

- 项目链接：https://github.com/navidrome/navidrome
- 适合借鉴：
  - 扫描、索引、增量更新与多客户端消费模型
  - 音乐库服务化的能力拆分方式
- 对 MusicSync 的直接价值：
  - 如果后续需要“局域网多端统一视图/轻服务端”，可减少架构试错

## 3. 建议先落地的标签规范（可转成代码规则）

建议先固定一版最小字段集与冲突优先级（先不追求大而全）：

- 最小字段集：
  - `title`
  - `artist`
  - `album`
  - `composer`
  - `trackNumber`
  - `discNumber`
  - `lyrics`
- 归一化建议：
  - 统一空白字符与分隔符
  - `track` / `disc` 统一成 `N` 或 `N/TOTAL` 表达
  - 统一 writer/composer 的映射入口
- 冲突优先级建议（可按容器逐步细化）：
  - 先选择信息完整度更高的 tag
  - 同等完整度下优先现代/高版本标签
  - 对明显异常值（空串、乱码占位）做降权

## 4. 分阶段实施建议（低风险）

1. 第一阶段：标签一致性收口
   - 固定字段字典、冲突优先级、异常值规则
   - 建立跨格式样本集（mp3/flac/ogg/m4a/ape）回归测试
2. 第二阶段：预览体验增强
   - 在预览侧增加“标签差异说明”和统一展示格式
   - 补充封面/歌词等可选信息的显式状态
3. 第三阶段：播放器能力补齐
   - 引入最小播放验证流（选中 -> 试听 -> 确认同步）
   - 再逐步增加队列、歌词、封面联动等体验项

## 5. 与当前项目现状的对应关系

根据现有代码结构，当前已具备：

- Flutter 主体 UI 架构与 settings/preview/execution 状态流
- LocalSend 风格的网络/传输能力基础
- `audio_metadata_reader` 的多容器标签读取（FLAC/Ogg/MP4/ID3/APE）

因此最合适的下一步不是继续扩来源，而是先把“标签语义统一层”补齐。
这会直接提升预览可信度与同步结果可预期性。

# MusicSync 开发实施方案

## 1. 目标

本方案用于指导 MusicSync 第一版的实际开发。目标是在 Windows 和 Android 上交付一个可用的局域网单向镜像同步工具，并为后续的设备发现、严格模式和更强校验能力预留扩展空间。

第一版交付目标：

- Flutter 客户端可同时运行在 Windows 与 Android
- 支持手动输入地址建立局域网连接
- 支持选择本机音乐目录
- 支持扫描目录并交换索引
- 支持预览 `A -> B` 镜像同步计划
- 支持执行复制与可选删除
- 支持冲突标记、进度、取消和错误日志
- 支持简单缓存

第一版方向约束：

- 当前版本先只做 `本机 -> 远端` 镜像
- “监听”与“连接”只表示网络会话建立方式，不表示复制方向
- 用户在本机选择的目录默认视为源目录
- 远端设备上被共享的目录默认视为目标目录
- `远端 -> 本机` 暂不进入第一版
- 当前可优先承诺的主路径是 `Windows -> Android`
- `Android -> Windows` 仍处于兼容性修复阶段，不作为当前稳定承诺路径

## 2. 开发原则

- 先打通完整链路，再补性能和体验
- 平台文件访问与业务逻辑分离
- 网络同步从一开始按“远端目录”思路设计
- 所有高风险操作先预览再执行
- 冲突不自动处理
- 删除默认关闭
- 模块之间通过接口协作，不跨层直接调用实现细节
- UI 只消费状态，不直接拼接核心业务逻辑

## 3. 技术栈建议

建议采用以下实现组合：

- Flutter SDK
- Dart 3
- 状态管理：`riverpod`
- 路由：`go_router`
- 不可变模型：`freezed` + `json_serializable`
- 本地存储：`isar` 或首版先用轻量 KV
- 日志：自定义日志服务，必要时接 `logger`
- Windows 路径处理：`path`
- 目录选择：
  - Windows：桌面目录选择插件
  - Android：平台目录访问桥接

选择 `riverpod` 的原因：

- 适合中等复杂度工程
- 依赖管理清晰
- 可以自然拆分连接状态、扫描状态、预览状态、执行状态

## 4. 建议目录结构

建议从一开始就按 feature + core 分层，而不是把所有逻辑堆到 `lib/` 根目录。

```text
lib/
  main.dart
  app/
    app.dart
    bootstrap.dart
    routes/
      app_router.dart
      route_names.dart
    theme/
      app_theme.dart
      app_colors.dart
      app_spacing.dart
    widgets/
      app_scaffold.dart
      status_badge.dart
      section_card.dart
  core/
    constants/
      app_constants.dart
      protocol_constants.dart
      storage_keys.dart
    errors/
      app_exception.dart
      file_access_exception.dart
      network_exception.dart
      sync_exception.dart
    logging/
      app_logger.dart
      log_event.dart
      log_level.dart
    utils/
      byte_format.dart
      date_time_utils.dart
      path_utils.dart
      retry.dart
      cancellable_operation.dart
  models/
    file_entry.dart
    file_entry.freezed.dart
    file_entry.g.dart
    scan_snapshot.dart
    scan_snapshot.freezed.dart
    scan_snapshot.g.dart
    diff_item.dart
    diff_item.freezed.dart
    diff_item.g.dart
    sync_plan.dart
    sync_plan.freezed.dart
    sync_plan.g.dart
    transfer_progress.dart
    transfer_progress.freezed.dart
    transfer_progress.g.dart
    device_info.dart
    device_info.freezed.dart
    device_info.g.dart
  services/
    file_access/
      file_access_gateway.dart
      file_access_entry.dart
      windows_file_access_gateway.dart
      android_file_access_gateway.dart
      file_access_provider.dart
    scanning/
      directory_scanner.dart
      scan_cache_service.dart
      scan_index_builder.dart
    diff/
      diff_engine.dart
      diff_policy.dart
      sync_plan_builder.dart
    sync/
      sync_orchestrator.dart
      sync_executor.dart
      copy_executor.dart
      delete_executor.dart
      conflict_detector.dart
      sync_task_controller.dart
    network/
      connection_service.dart
      listener_service.dart
      peer_session.dart
      protocol/
        protocol_message.dart
        protocol_codec.dart
        protocol_message_type.dart
        messages/
          hello_message.dart
          hello_ack_message.dart
          scan_request_message.dart
          scan_response_message.dart
          plan_preview_message.dart
          plan_confirm_message.dart
          copy_request_message.dart
          copy_chunk_message.dart
          copy_complete_message.dart
          delete_request_message.dart
          progress_message.dart
          error_message.dart
          cancel_message.dart
          done_message.dart
    storage/
      app_storage.dart
      cache_store.dart
      settings_store.dart
      recent_peers_store.dart
  features/
    home/
      presentation/
        pages/
          home_page.dart
        widgets/
          local_directory_card.dart
          connection_card.dart
          listener_card.dart
      state/
        home_controller.dart
        home_state.dart
    connection/
      presentation/
        pages/
          connect_page.dart
        widgets/
          peer_address_form.dart
          connection_status_panel.dart
      state/
        connection_controller.dart
        connection_state.dart
    directory/
      presentation/
        widgets/
          directory_picker_tile.dart
          permission_banner.dart
      state/
        directory_controller.dart
        directory_state.dart
    preview/
      presentation/
        pages/
          preview_page.dart
        widgets/
          sync_summary_card.dart
          diff_list_view.dart
          delete_option_tile.dart
          conflict_section.dart
      state/
        preview_controller.dart
        preview_state.dart
    execution/
      presentation/
        pages/
          execution_page.dart
          result_page.dart
        widgets/
          transfer_progress_panel.dart
          current_file_panel.dart
          sync_log_list.dart
      state/
        execution_controller.dart
        execution_state.dart
    settings/
      presentation/
        pages/
          settings_page.dart
      state/
        settings_controller.dart
        settings_state.dart
  platform/
    channels/
      directory_access_channel.dart
      transfer_channel.dart
    android/
      placeholder.md
    windows/
      placeholder.md
```

说明：

- `core/` 放跨 feature 通用的基础设施
- `models/` 放纯数据结构
- `services/` 放领域服务与平台接入
- `features/` 放页面、交互状态和局部 UI 组件
- `platform/` 预留平台桥接说明和原生实现入口

其中部分文件可以先留空或只写接口，后续按里程碑逐步填充。

## 5. 分层约束

建议明确以下约束，避免项目长大后结构失控：

- `features/` 可以依赖 `services/`、`models/`、`core/`
- `services/` 可以依赖 `models/`、`core/`
- `models/` 只依赖 `core/` 中极少量基础类型
- `services/` 之间只通过清晰接口协作，避免循环依赖
- 页面文件不直接创建 TCP 连接、不直接扫描目录、不直接操作缓存

推荐调用路径：

- UI 事件
- controller / notifier
- service
- gateway / repository

而不是：

- widget 直接操作 socket 或 file API

## 6. 关键数据结构

### 6.1 FileEntry

建议字段：

- `relativePath`
- `isDirectory`
- `size`
- `modifiedTime`
- `fingerprint`
- `sourceId`
- `entryId`

说明：

- `relativePath` 是差异分析主键
- `fingerprint` 第一版可为空，用于缓存扩展
- `entryId` 用于平台文件访问层定位实际条目，避免业务层依赖真实路径格式

建议定义示意：

```dart
class FileEntry {
  final String relativePath;
  final String entryId;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
  final String? fingerprint;
  final String sourceId;
}
```

### 6.2 ScanSnapshot

建议字段：

- `rootId`
- `scannedAt`
- `entries`
- `cacheVersion`
- `rootDisplayName`
- `deviceId`

### 6.3 DiffItem

建议字段：

- `type`
- `relativePath`
- `sourceEntry`
- `targetEntry`
- `reason`

`type` 取值建议：

- `copy`
- `delete`
- `conflict`
- `skip`

### 6.4 SyncPlan

建议字段：

- `copyItems`
- `deleteItems`
- `conflictItems`
- `summary`
- `sourceDevice`
- `targetDevice`
- `deleteEnabled`

建议定义示意：

```dart
class SyncPlan {
  final List<DiffItem> copyItems;
  final List<DiffItem> deleteItems;
  final List<DiffItem> conflictItems;
  final SyncPlanSummary summary;
  final bool deleteEnabled;
}
```

### 6.5 TransferProgress

建议字段：

- `stage`
- `currentPath`
- `processedFiles`
- `totalFiles`
- `processedBytes`
- `totalBytes`

建议枚举：

```dart
enum SyncStage {
  idle,
  connecting,
  scanningSource,
  scanningTarget,
  buildingPlan,
  awaitingConfirmation,
  copying,
  deleting,
  completed,
  cancelled,
  failed,
}
```

## 7. 平台文件访问设计

### 7.1 抽象接口

建议定义统一接口，例如 `FileAccessGateway`：

- `pickDirectory()`
- `listChildren(directoryId)`
- `stat(entryId)`
- `openRead(entryId)`
- `openWrite(entryId)`
- `createDirectory(parentId, name)`
- `deleteEntry(entryId)`
- `resolveRootDisplayName(rootId)`

业务层不直接关心平台路径细节，只处理抽象标识和标准元数据。

建议接口示意：

```dart
abstract class FileAccessGateway {
  Future<DirectoryHandle?> pickDirectory();
  Future<List<FileAccessEntry>> listChildren(String directoryId);
  Future<FileAccessEntry> stat(String entryId);
  Stream<List<int>> openRead(String entryId);
  Future<FileWriteSession> openWrite(String parentId, String name);
  Future<String> createDirectory(String parentId, String name);
  Future<void> deleteEntry(String entryId);
}
```

补充建议：

- `DirectoryHandle` 用于保存已授权根目录标识
- `entryId` 与 `relativePath` 分离
- 写入接口最好返回 session，而不是一次性写完，方便网络流式落盘

### 7.2 Windows 实现

Windows 实现优先使用本地文件路径模型：

- 目录选择
- 递归扫描
- 文件流式读取
- 写入和删除

重点关注：

- 大目录递归性能
- 异常处理
- 长路径兼容

建议内部类：

- `WindowsDirectoryHandle`
- `WindowsFileAccessEntry`
- `WindowsFileWriteSession`

### 7.3 Android 实现

Android 实现重点是目录授权和持久访问。

第一版必须解决：

- 用户选择目录
- 保存授权状态
- 基于已授权目录进行枚举
- 执行写入、创建目录、删除

这里建议尽早验证原型，不要等业务逻辑完成后再补 Android 文件访问。

建议内部类：

- `AndroidDirectoryHandle`
- `AndroidDocumentEntry`
- `AndroidFileWriteSession`

同时预留：

- 权限恢复失败处理
- 根目录失效提示
- 用户重新授权流程

## 8. 网络协议设计

### 8.1 连接模型

首版采用：

- 目标端启动监听服务
- 源端手动输入目标端地址并发起连接

连接建立后进行握手：

- 协议版本校验
- 设备信息交换
- 目录根信息交换

建议由 `PeerSession` 统一管理 socket 生命周期、读写循环和请求相关性。

### 8.2 消息帧建议

为了让协议后续易扩展，建议不要直接裸发 JSON 行文本，而是定义统一消息帧：

```text
[magic][version][messageType][requestId][payloadLength][payloadBytes]
```

建议：

- 固定头 + 变长 payload
- 控制消息用 JSON
- 文件块消息 payload 直接传二进制

这样后面做大文件传输和进度统计会更顺。

### 8.3 消息类型

建议最小消息集合包括：

- `hello`
- `helloAck`
- `scanRequest`
- `scanResponse`
- `planPreview`
- `planConfirm`
- `copyRequest`
- `copyChunk`
- `copyComplete`
- `deleteRequest`
- `progress`
- `error`
- `cancel`
- `done`

建议补充两个字段：

- `requestId`
- `timestamp`

### 8.4 消息模型示意

```dart
sealed class ProtocolMessage {
  final String requestId;
  final DateTime timestamp;
}

class HelloMessage extends ProtocolMessage {
  final String deviceId;
  final String deviceName;
  final String appVersion;
  final int protocolVersion;
}
```

### 8.5 文件传输

复制流程建议：

1. 源端发送复制请求
2. 目标端确认可写入
3. 源端按块发送文件内容
4. 目标端持续汇报接收进度
5. 完成后双方确认单文件完成

分块大小首版可固定，后续再优化。

建议首版就定义一个传输配置：

```dart
class TransferConfig {
  final int chunkSize;
  final Duration socketTimeout;
  final bool flushEveryChunk;
}
```

默认可先用：

- `chunkSize = 256 KB` 或 `512 KB`
- 大文件传输走顺序流，不做并行分片

当前实现备注：

- 目前仍使用基于 `Socket` 的自定义协议，不是 `HTTP` 或 `HTTPS`
- 当前文件块在部分链路上仍经过 `JSON + base64 + MethodChannel` 往返
- 该实现优先保证功能跑通，不是最终性能方案
- 因此传输速度偏保守属于预期内现象

## 9. 差异分析实现

### 9.1 比较规则

使用 `relativePath` 对齐文件。

判断逻辑：

- 仅源端存在：`copy`
- 仅目标端存在：
  - 删除开关开启：`delete`
  - 删除开关关闭：`skip`
- 双方都存在且 `size`、`modifiedTime` 一致：`skip`
- 双方都存在但元数据不一致：`conflict`

### 9.2 伪代码示意

```dart
SyncPlan buildPlan({
  required Map<String, FileEntry> sourceEntries,
  required Map<String, FileEntry> targetEntries,
  required bool deleteEnabled,
}) {
  final copyItems = <DiffItem>[];
  final deleteItems = <DiffItem>[];
  final conflictItems = <DiffItem>[];

  final allPaths = {...sourceEntries.keys, ...targetEntries.keys}.toList()..sort();

  for (final path in allPaths) {
    final source = sourceEntries[path];
    final target = targetEntries[path];

    if (source != null && target == null) {
      copyItems.add(DiffItem.copy(path: path, source: source));
      continue;
    }

    if (source == null && target != null) {
      if (deleteEnabled) {
        deleteItems.add(DiffItem.delete(path: path, target: target));
      }
      continue;
    }

    if (source == null || target == null) {
      continue;
    }

    final isSame = source.size == target.size &&
        source.modifiedTime == target.modifiedTime;

    if (isSame) {
      continue;
    }

    conflictItems.add(DiffItem.conflict(
      path: path,
      source: source,
      target: target,
      reason: 'metadata_mismatch',
    ));
  }

  return SyncPlan(
    copyItems: copyItems,
    deleteItems: deleteItems,
    conflictItems: conflictItems,
    summary: SyncPlanSummary.fromItems(copyItems, deleteItems, conflictItems),
    deleteEnabled: deleteEnabled,
  );
}
```

### 9.3 为什么不自动覆盖

你已经决定第一版冲突统一标记。工程上这有两个好处：

- 避免错误地把“不同版本文件”当成“旧版本文件”
- 不需要在第一版引入复杂优先级策略

## 10. 扫描与缓存实现

### 10.1 扫描策略

建议扫描器职责保持单一：

- 从根目录递归枚举条目
- 过滤系统无关项
- 生成标准化 `FileEntry`
- 不在扫描器里直接做差异分析和同步计划

建议内部拆分：

- `DirectoryScanner`
- `ScanIndexBuilder`
- `ScanCacheService`

### 10.2 扫描伪代码

```dart
class DirectoryScanner {
  final FileAccessGateway gateway;
  final ScanCacheService cacheService;

  Future<ScanSnapshot> scan(DirectoryHandle root) async {
    final entries = <FileEntry>[];
    await _walk(root.entryId, '', entries);
    return ScanSnapshot(
      rootId: root.entryId,
      rootDisplayName: root.displayName,
      scannedAt: DateTime.now(),
      entries: entries,
      cacheVersion: 1,
    );
  }

  Future<void> _walk(
    String directoryId,
    String relativeBase,
    List<FileEntry> output,
  ) async {
    final children = await gateway.listChildren(directoryId);
    for (final child in children) {
      final nextPath = relativeBase.isEmpty
          ? child.name
          : '$relativeBase/${child.name}';

      output.add(_toFileEntry(child, nextPath));

      if (child.isDirectory) {
        await _walk(child.entryId, nextPath, output);
      }
    }
  }
}
```

### 10.3 缓存内容

建议缓存：

- `relativePath`
- `size`
- `modifiedTime`
- `lastSeenAt`
- `fingerprint`，可选

### 10.4 缓存使用方式

扫描时：

- 如果路径存在且 `size`、`modifiedTime` 未变化，可直接复用缓存元数据
- 如果变化，则重新生成条目

### 10.5 缓存键建议

首版缓存键建议组合：

- `deviceId`
- `rootId`
- `relativePath`

这样可以避免不同设备或不同根目录间缓存串用。

### 10.6 第一版缓存存储

第一版可使用轻量本地存储方案即可，不需要一开始就设计复杂数据库层。

重点是：

- 能稳定读写
- 能按根目录区分缓存
- 能处理路径删除和缓存过期

## 11. 同步执行设计

### 11.1 核心职责拆分

建议同步执行不要写成一个超大 service，而是拆成：

- `SyncOrchestrator`
  - 驱动整个同步生命周期
- `SyncExecutor`
  - 按计划执行 copy / delete
- `CopyExecutor`
  - 单文件复制
- `DeleteExecutor`
  - 删除执行
- `SyncTaskController`
  - 取消、暂停预留、状态通知

### 11.2 Orchestrator 伪代码

```dart
class SyncOrchestrator {
  final DirectoryScanner scanner;
  final DiffEngine diffEngine;
  final SyncExecutor syncExecutor;
  final ConnectionService connectionService;

  Future<SyncPlan> preparePlan(PrepareSyncInput input) async {
    final sourceSnapshot = await scanner.scan(input.sourceRoot);
    final targetSnapshot = await connectionService.fetchRemoteSnapshot(
      input.targetPeer,
      input.targetRootId,
    );

    return diffEngine.buildPlan(
      source: sourceSnapshot,
      target: targetSnapshot,
      deleteEnabled: input.deleteEnabled,
    );
  }

  Future<SyncResult> executePlan(
    SyncPlan plan,
    SyncTaskController controller,
  ) {
    return syncExecutor.execute(plan, controller);
  }
}
```

### 11.3 执行顺序建议

为了降低失败时的混乱度，建议执行顺序为：

1. 创建缺失目录
2. 复制文件
3. 最后删除目标端多余文件

不要先删再拷贝。这样即使任务中途失败，也更接近“保守同步”。

### 11.4 取消语义

取消操作建议定义为：

- 不再开始新的文件任务
- 当前正在传输的文件尽快中断
- 已成功写入的文件保留
- 删除阶段一旦开始，单项删除完成后再响应取消

第一版不做事务回滚。

## 12. UI 页面建议

### 12.1 首页 / 工作台

展示：

- 源目录选择
- 目标目录选择
- 远端地址输入
- 连接状态
- 差异预览摘要
- 差异列表
- 执行按钮
- 执行进度
- 结果摘要入口

实现过程中的页面调整记录：

- 初版采用“首页 -> 预览页 -> 执行页 -> 结果页”的调试友好结构
- 在本地链路打通后，已将首页升级为主工作台
- 当前主流程应以首页工作台为准，预览页和执行页仅作为过渡页面保留

这样处理的原因是：

- 对于同步工具，用户更需要单页操作闭环，而不是多步表单式跳转
- 源目录、目标目录、差异预览和同步动作天然属于同一上下文
- 这样也有利于后续加入远端目标、连接状态和局域网执行进度

### 12.2 连接页或连接区块

展示：

- 当前连接状态
- 本机地址
- 远端地址
- 断开重连操作

### 12.3 预览页

展示：

- 待复制文件数
- 待删除文件数
- 冲突文件数
- 总大小估算
- 删除选项开关
- 执行同步按钮

建议把复制、删除、冲突分区展示，避免用户误解。

建议预览页顶部就显示一句强提示：

- 开启删除后，目标端多余文件将被移除

说明：

- 当前产品方向已将预览能力并回首页工作台
- 本节保留主要用于说明“预览模块本身”仍然存在，而不意味着最终必须保留独立预览页

### 12.4 执行页

展示：

- 当前阶段
- 当前处理文件
- 总体进度
- 当前文件进度
- 日志列表
- 取消按钮

说明：

- 当前执行能力也已部分并回首页工作台
- 独立执行页后续可能被弱化或只保留为高级调试页面

### 12.5 结果页

展示：

- 成功复制数量
- 成功删除数量
- 冲突数量
- 失败数量
- 错误摘要

## 13. 状态管理建议

推荐将状态拆成四条主线：

- `directoryState`
- `connectionState`
- `previewState`
- `executionState`

避免一个全局超大 `AppState`。

### 13.1 ConnectionState

建议状态：

- `idle`
- `listening`
- `connecting`
- `connected`
- `disconnected`
- `failed`

### 13.2 PreviewState

建议状态：

- `idle`
- `loading`
- `loaded`
- `empty`
- `failed`

### 13.3 ExecutionState

建议状态：

- `idle`
- `running`
- `cancelling`
- `completed`
- `failed`

## 14. 执行流程

建议的完整流程如下：

1. 用户在目标端选择目录并启动监听
2. 用户在源端选择目录并输入目标端地址
3. 双方建立连接并完成握手
4. 双方各自扫描本地目录
5. 源端拉取目标端索引
6. 源端生成同步计划
7. 向用户展示预览
8. 用户确认是否执行
9. 按计划依次执行复制和可选删除
10. 展示结果摘要和错误日志

## 15. 错误处理建议

建议统一错误模型，避免直接向 UI 暴露底层异常字符串。

可定义：

- `UserVisibleError`
- `RecoverableError`
- `FatalSyncError`

错误来源至少分四类：

- 目录授权失败
- 网络连接失败
- 文件读写失败
- 协议不兼容或消息非法

日志层记录原始异常，UI 层展示人类可读信息。

## 16. 里程碑建议

### 里程碑 M1：本地基础能力

目标：

- Flutter 工程初始化
- 基础路由与状态管理搭建
- Windows 本地目录选择和扫描
- `FileEntry` 与 `ScanSnapshot` 跑通
- 基础目录结构建立
- 预留 Android 文件访问接口

验收标准：

- 能在 Windows 上选择目录并看到扫描结果

### 里程碑 M2：Android 文件访问原型

目标：

- Android 目录选择原型
- 已授权目录重新打开能力
- Android 目录枚举可跑通

验收标准：

- Android 能稳定选择并重新访问目录

### 里程碑 M3：网络连接闭环

目标：

- TCP 监听与连接
- 握手消息
- 双方索引交换

验收标准：

- Windows 与 Android 能建立连接并互换目录索引

### 里程碑 M4：差异预览

目标：

- 差异分析器完成
- 预览页完成
- 删除开关和冲突展示完成
- 本地目标目录真正接入差异计算
- 首页工作台完成预览整合

验收标准：

- 能稳定生成可读的同步计划
- 本地两个目录内容一致时不再错误显示全部复制

### 里程碑 M5：同步执行

目标：

- 文件复制
- 目录创建
- 可选删除
- 进度与取消
- 首页工作台完成执行整合

验收标准：

- 能完成一次真实的 `A -> B` 镜像同步

### 里程碑 M6：缓存与稳定性

目标：

- 简单缓存
- 错误处理优化
- 结果页与日志优化

验收标准：

- 重复扫描更快，失败场景可定位

## 17. 测试重点

第一版测试应优先覆盖：

- 空目录同步
- 小量文件同步
- 大文件同步
- 包含子目录的同步
- 目标端额外文件删除
- 同名不同内容的冲突识别
- 连接断开
- 取消中途同步
- Android 目录授权失效
- 不可写文件或空间不足

建议测试层也预留目录：

```text
test/
  unit/
    diff/
      diff_engine_test.dart
      sync_plan_builder_test.dart
    scanning/
      scan_cache_service_test.dart
    protocol/
      protocol_codec_test.dart
  integration/
    windows/
      local_scan_flow_test.dart
    sync/
      preview_flow_test.dart
      execute_flow_test.dart
```

## 18. 第一版 TODO

以下内容明确留到后续版本：

- 自动发现局域网设备
- 严格模式
- 哈希校验增强
- 自动重试
- 断点续传
- 冲突手动处理
- 过滤规则
- 同步历史记录

建议在代码里预留但先不实现的文件：

- `services/network/discovery_service.dart`
- `services/sync/hash_verifier.dart`
- `services/sync/resume_transfer_service.dart`
- `features/history/presentation/pages/history_page.dart`
- `features/history/state/history_controller.dart`
- `services/storage/sync_history_store.dart`

这样后续扩展时，目录结构不会再大改。

## 19. 当前最重要的实施建议

如果准备马上开工，优先顺序建议是：

1. 先验证 Android 目录访问原型
2. 再搭建统一文件访问抽象
3. 然后实现 TCP 连接和索引交换
4. 再做差异分析和预览
5. 最后补复制、删除、进度和缓存

原因很直接：Android 目录访问和跨设备连接是这版方案中最容易导致返工的部分，必须优先验证。

## 20. 当前开发进度

截至当前实现，已完成的内容如下：

- Flutter 工程初始化完成
- Android / Windows 平台目录已生成
- `riverpod + go_router + l10n` 基础设施已接入
- Windows 本地目录选择与文件访问已打通
- 扫描器、差异分析器、预览状态与执行状态已建立
- 首页已升级为单页工作台
  - 源目录选择
  - 本地目标目录选择
  - 远端地址输入
  - 差异预览
  - 执行进度
  - 结果入口
- 预览默认展示完整差异结果
- 删除动作改为执行前确认，而不是通过预览开关控制
- 本地双目录真实差异预览已完成
  - 不再使用“空目标目录占位”生成预览
  - 本地目标目录会参与真实扫描与 diff
- 本地复制执行闭环已完成
  - 目标目录可选
  - 复制进度可见
  - 结果页可查看复制结果
- i18n 基础结构已建立，并已覆盖当前主要页面文案
- 最近使用能力已补充
  - 最近目录
  - 最近连接地址
- Android 目录选择、目录枚举、基本写入与删除桥接已补入首版
- 局域网远端执行最小闭环已接入
  - 远端预览可生成
  - 远端执行入口已接入
  - Android 源端流式读取已补齐
  - 失败时会主动中止远端写入并清理半成品文件

当前尚未完成但已进入明确待办的部分：

- 更明确的冲突处理与结果详情
- Android 扫描稳定性与 provider 兼容性
- `Android -> Windows` 方向的稳定性修复
- 远端执行的性能优化
- 更完整的断链恢复与用户提示
- 残留临时文件的更强生命周期治理
  - 当前先采用保守策略
  - 不做启动即全盘自动清理
  - 后续若要支持断点续传，再引入 transfer journal 或可恢复元数据

## 21. 当前 UI 调整记录

实际开发过程中，页面结构已经发生一次明确调整：

- 初始结构：
  - 首页
  - 预览页
  - 执行页
  - 结果页
- 当前结构：
  - 首页作为主工作台
  - 预览能力并入首页
  - 执行能力并入首页
  - 结果页保留
  - 预览页 / 执行页保留为过渡页面，后续可能弱化或移除

这样调整后的收益：

- 用户在一个上下文内完成“选源目录、选目标目录、看差异、执行同步”
- 状态不再在多个页面之间来回传递
- 更符合文件同步工具而不是多步骤表单工具的使用方式

删除交互也做了额外调整：

- 初版曾使用“删除目标端多余文件”开关影响预览行为
- 当前已改为“预览总是显示完整差异，执行前若有删除项则弹窗确认”

这样处理后：

- 预览更真实
- 风险提示更接近实际操作时刻
- 用户不需要理解“开关到底影响预览还是影响执行”这类歧义

后续若继续优化 UI，应优先保持这一工作台模型，而不是回到分散多页流程。

## 22. 最新开发记录

最近一轮已完成以下调整：

- 远端写入已改为“临时文件 -> 完成后重命名”
  - 远端接收文件时先写入 `*.music_sync_tmp`
  - 只有 `finishCopy` 成功后才重命名为正式文件
  - `abortCopy` 或连接断开时会尝试删除临时文件
  - 这样可以避免把半传输文件直接暴露为正式文件
- 针对冷启动残留临时文件，已采用保守处理
  - 扫描器默认忽略 `*.music_sync_tmp`
  - 这些残留不再进入预览、删除项或冲突项
  - 首页已补充“清理未完成传输残留”按钮
  - 当前支持对“本地源目录”和“本地调试目标目录”手动递归清理
  - 暂不做启动自动清理，因为当前没有 transfer journal，无法可靠区分“确实应删”的临时文件与未来可恢复现场
- 断连与半成品回归测试已补齐
  - 已验证远端正常完成时会把临时文件重命名为正式文件
  - 已验证连接中断时会删除当前会话产生的临时文件
  - 已验证扫描阶段会忽略 `*.music_sync_tmp`
  - 已补充手动清理服务的递归删除测试

- 执行结果已补充模式语义
  - 结果页会区分“本地调试复制”与“远端同步”
  - 首页与结果页的状态语义进一步对齐，减少本地调试链路与局域网链路混淆
- 执行状态清理语义已收口
  - 切换目录、刷新连接、断开连接时，不再顺带清空本地调试目标目录
  - 现在只清空预览与执行结果，减少重复选择目录的摩擦
- 首页已补充主动断开连接按钮
  - 连接错设备或需要重连时，可直接在工作台断开
  - 若本机仍处于监听状态，断开远端后会继续保留监听
- 首页执行区已补充“停止同步”按钮
  - 执行中可主动中断本地调试复制或远端同步
  - 当前语义为“尽快停止”，而不是事务回滚
  - 本地复制会把正在写入的临时文件删除
  - 远端复制会发送 `abortCopy`，由远端删除未完成临时文件
  - 删除阶段只会在下一项开始前响应取消，不回滚已完成删除
- 执行完成后的预览状态已收口
  - 无论是同步完成还是手动停止，首页都会按当前模式自动重建预览
  - 本地调试模式会重新扫描本地目标目录
  - 远端模式会先刷新远端索引，再重建远端预览
  - 这样可以避免执行后仍然显示旧计划，减少“已经同步完但页面还显示待复制”的混淆
- 远端目录就绪提示已增强
  - 首页远端卡片会明确区分“远端共享目录已就绪”与“远端尚未选择共享目录”
  - 这样在远端未选目录时，不必等到点击生成预览后才看到错误
- 远端预览主流程已进一步收口
  - “生成远端预览”现在会先自动刷新远端索引，再生成同步计划
  - “刷新远端索引”暂时保留为手动校准与调试入口
  - 交互上减少了用户反复执行两个前置步骤的负担
- 首页关键操作已补充忙碌态互斥
  - 连接中、预览生成中、执行中时，关键按钮会临时禁用
  - 这样可以避免重复点击导致的状态重入与界面混乱
- 路由层已进一步收口到首页工作台
  - 旧的 `preview` / `execution` 路由现在直接回到首页
  - 预览与执行页面文件暂时保留，但不再作为正式主流程入口
- 执行区与结果页文案已按当前真实能力修正
  - 不再使用“远端执行尚未接通”这类过时提示
  - 结果页的建议文案会按本地调试 / 远端同步模式分别显示
- 连接错误提示已开始做归一化
  - 常见的未连接、握手失败、远端未选目录、拒绝连接、超时等情况已转成更可读的用户提示
  - 当前目标是逐步减少底层异常字符串直接暴露到工作台
- 目录与预览阶段的异常文案也已开始收口
  - 常见的权限拒绝、目录失效、扫描超时等情况已优先转为用户可读提示
  - 这样可以减少 `PathAccessException` 一类底层异常直接暴露到界面
- 过渡代码已进一步清理
  - 原 `preview` / `execution` 过渡页面文件已移除
  - 路由层与正式入口现在只保留首页工作台、结果页、设置页
- 执行与远端链路错误模型继续收口
  - 执行状态已统一剥离常见 `SocketException:` 前缀
  - 目录、预览、连接、执行四条状态线都已有基础错误归一化能力
- 关键回归测试已补齐
  - 执行状态清理
  - 连接断开后的状态清理
  - 远端预览“先刷新再生成”的序列
  - 常见错误文案归一化
- 已补充轻量目录预检
  - 选择目录后不会立刻全量扫描
  - 当前只做轻量可访问性校验与浅层样本预检
  - 如果目录疑似过大、浅层结构过密、含访问受限子目录，或看起来像系统/缓存目录，会给出软提示
  - 该提示不会阻止用户继续生成预览，只用于提前说明风险
- 自动发现局域网设备第一版已接入
  - 当前采用 UDP 广播发现
  - 设备进入监听状态后会定期广播自身监听信息
  - 应用会在后台接收发现包，并在首页展示“发现到的设备”
  - 点击发现项可直接回填地址输入框
  - 当前目标是降低手动输入 IP 的频率，不承诺 mDNS 级别的稳定发现能力
- 预览类型筛选改为热切换
  - 点击“生成预览”时只做一次真实扫描
  - 后续切换 `全部 / flac / mp3 ...` 时，只基于已缓存快照重算 `SyncPlan`
  - 不再因为切换类型而重复全量遍历目录
- 局域网连接从“假连接”升级为“真握手”
  - 已建立 `PeerSession`
  - 已引入最小 JSON Line 协议
  - 已实现 `hello / helloAck / scanRequest / scanResponse / error`
- 监听端现在可以响应远端扫描请求
  - 监听中的设备会使用当前已选目录生成 `ScanSnapshot`
  - 连接端在握手后会立刻请求远端索引
- 首页远端卡片已补充基础可视状态
  - 可显示已连接设备名
  - 可显示远端根目录名
  - 可显示远端文件数量
  - 可手动刷新远端索引
- 第一版产品方向已收敛为 `本机 -> 远端`
  - 不再把“谁监听 / 谁连接”混同为“谁复制到谁”
  - 首页会明确提示当前复制方向
  - 局域网预览入口按 `本机 -> 远端` 固定生成计划
- 最近使用入口已补充到首页
  - 最近目录可直接回填
  - 最近地址可直接回填
- Android 平台桥接继续补齐
  - 已支持目录选择
  - 已支持目录枚举与元数据读取
  - 已支持打开读取流
  - 已支持创建目录
  - 已支持打开写入流
  - 已支持删除条目
- 远端执行失败清理已补齐
  - 失败后会发送 `abortCopy`
  - 远端会关闭写入句柄
  - 远端会删除半成品文件，避免遗留被占用的 `0 KB` 文件
- 扫描阶段的“部分失败”提示已补齐
  - 根目录不可访问时，仍然直接视为扫描失败
  - 子目录不可访问时，不再静默吞掉
  - 现在会把被跳过的子目录作为警告带回预览摘要
  - 用户可以继续生成计划，但界面会明确提示“结果可能不完整”
- 新增协议编解码单测，避免后续扩协议时把基础消息层改坏

当前局域网能力的真实边界：

- 已可监听
- 已可连接
- 已可完成设备握手
- 已可请求并接收远端目录索引
- 已可触发最小远端复制 / 删除流程
- 还没有自动发现局域网设备
- Android 设备切后台后，连接可能被系统回收，不支持后台稳定同步
- 当前阶段必须以“目标设备保持前台”作为测试前提
- `Windows -> Android` 已能完成完整传输，但性能仍偏保守
- `Android -> Windows` 仍可能出现扫描或 provider 兼容性问题

下一阶段应继续：

1. 优先继续稳定 `Windows -> Android` 主路径
2. 修复 Android 扫描失败与 `Android -> Windows` 兼容问题
3. 为断链和后台切换补充更明确的用户提示
4. 在主路径稳定后，再进入传输性能优化
5. 继续收敛扫描警告、结果页语义和错误模型，减少“看起来成功但语义不清”的状态

当前不建议立刻做深优化，原因如下：

- 现在的主要问题仍然是平台兼容性和链路稳定性，不是纯吞吐问题
- 如果现在直接重做传输协议，容易把刚刚跑通的主路径重新打散
- 更合理的顺序是先把稳定性边界摸清，再替换 `base64 / MethodChannel / chunk` 这一层

当前已经确认的性能结论：

- 目前传输不是 `HTTP`，也不是 `HTTPS`
- 当前慢的主要原因不是“是否使用 HTTPS”
- 当前慢主要来自：
  - `JSON + base64` 带来的体积和编码开销
  - Flutter 与 Android 原生之间的 `MethodChannel` 高频往返
  - 当前仍采用顺序、保守的分块传输策略

## 23. 首个里程碑提交状态

截至首个里程碑 commit，当前仓库已经具备以下基线能力：

- 首页工作台已收口为正式主流程
- Windows / Android 目录访问主链路已打通
- 本地预览、本地调试复制、局域网远端同步均可执行
- 远端传输采用 `*.music_sync_tmp` 临时文件落盘，再重命名为正式文件
- 传输中断或手动停止时，会尽量清理未完成临时文件
- 扫描默认忽略 `*.music_sync_tmp`
- 首页已提供手动清理未完成传输残留入口
- 执行完成或手动停止后，会自动重建当前预览
- 最近目录、最近地址、设备发现 v1、错误归一化、轻量目录预检已接入
- 单元测试和基础 widget 测试已覆盖当前关键回归点

当前可以视为“首版局域网同步主流程闭环已建立”，适合在此基础上进入第二轮开发。

### 压缩上下文

若后续需要快速恢复上下文，可按以下摘要理解当前状态：

- 产品方向：
  - 第一版固定为 `本机 -> 远端`
  - 主承诺路径是 `Windows -> Android`
  - `Android -> Windows` 仍不视为稳定路径
- 主流程：
  - 选本地源目录
  - 连接远端并刷新索引
  - 生成远端预览
  - 执行远端同步
  - 自动刷新预览
- 当前已知边界：
  - Android 目标端必须保持前台
  - 协议仍是保守实现，性能不是当前主目标
  - 冷启动后无法自动识别并清理所有残留临时文件，因此采用“扫描忽略 + 手动清理”保守策略
- 当前更适合的下一轮方向：
  1. 大量差异项列表性能优化
  2. 结果态与执行态展示继续收口
  3. 设备发现与远端目录交互体验继续打磨
  4. 主路径稳定后，再进入协议 / 吞吐优化

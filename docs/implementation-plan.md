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
- Android `MethodChannel` 写入去 base64
- 传输取消时主动中断正在进行的 HTTP 上传
- 上传吞吐统计与诊断日志
- 小文件批量或有限并发传输
- 证书 fingerprint / pinning

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
4. 在主路径稳定后，再进入 Android 写入层与吞吐优化
5. 继续收敛扫描警告、结果页语义和错误模型，减少“看起来成功但语义不清”的状态

当前不建议继续扩大协议层重构，原因如下：

- 现在的主要问题仍然是平台兼容性和链路稳定性，不是纯吞吐问题
- 传输协议主路径已经收口到 HTTP 控制面 + `stream-v1` 文件流上传
- 更合理的顺序是先把稳定性边界摸清，再继续优化 Android 写入层和取消语义

当前已经确认的性能结论：

- 当前控制面已使用 `HTTP / HTTPS`
- 当前文件内容传输已切到单请求二进制流上传
- 当前慢的主要原因不是“是否使用 HTTPS”
- 当前慢主要来自：
  - Android 侧写入仍经过 `MethodChannel`
  - Flutter 与 Android 原生之间的高频字节写入往返
  - 当前仍采用单文件串行传输策略

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

## 24. 第二轮开发进行中

当前第二轮已完成的阶段性优化：

- 差异列表渲染已做第一轮轻量化
  - `PlanItemList` 从较重的 `ListTile + separator` 改为定高轻量行
  - 已增加显式滚动条，降低大量条目时的滚动抖动与渲染开销
  - 当前分组条目数会直接显示在计划项区域，便于快速判断筛选结果
- 执行态与结果态展示已进一步收口
  - 首页进度区现在会直接显示执行状态
  - 结果页会明确显示“已完成 / 已取消 / 失败 / 空闲”
- 远端交互提示已增强一轮
  - 首页会显示远端索引时间
  - 预览摘要会显示当前目标快照时间
  - 这样可以更容易判断当前预览是否基于最新远端索引

当前这一轮仍属于“低风险体验优化”，尚未进入协议层或高成本性能改造。

## 25. 第二轮开发补充进展

本轮又继续收口了两类问题：

- 首页工作台新增“当前流程”区块
  - 会直接显示当前是否已选择本地目录
  - 是否已建立远端连接
  - 是否已加载远端索引
  - 是否已生成可执行的远端预览
  - 同时给出一个明确的“下一步”提示，减少测试时靠自己推断状态
- 错误文案继续统一
  - `directory / connection / preview / execution` 四类状态中的剩余英文兜底文案已继续收口
  - Windows 访问失败、连接拒绝、连接超时、远端断开等场景现在默认走统一中文提示

这一步的目的不是增加新功能，而是降低后续联调成本。当前首页已经更接近“引导式工作台”而不是一堆并列按钮。

## 26. 首页主流程重排

在进一步联调时，实际使用流程暴露出新的问题：

- 用户需要先在手机打开监听
- 回到电脑后要滚动很长页面才能找到“远端目标”
- 连接失败后，页面才用错误提示告诉用户“本地还没选目录 / 远端还没选目录”
- 每补齐一个前置条件，都要重新点一次连接
- 最后还要继续往下找“生成远端预览”

这说明原首页虽然功能齐，但仍然偏向“开发工作台”，而不是“可发布的首版交互”。

因此本轮已开始把首页按单向同步真实流程重排：

- 把“连接远端设备”提前为步骤 1
- 把“选择本地源目录”收为步骤 2
- 把“差异预览”收为步骤 3
- 把“执行同步”收为步骤 4
- 本地调试目标被降级到“高级与调试”区域，避免继续干扰正式主路径

同时新增了一条自动化行为：

- 当本地源目录与远端目录索引都已就绪时，首页会自动生成远端预览
- 用户不再必须手动再点一次“生成远端预览”才能继续

另外，设置页现在已有第一个真正生效的运行配置：

- `启动时自动开启监听`
  - 默认关闭
  - 开启后，应用启动后会自动在默认端口开始监听
- 该设置只影响“是否自动进入监听状态”，不改变同步方向语义
- 因此它不会和未来可能新增的其他联网模式产生直接冲突

## 27. 连接与远端目录状态解耦

这一轮继续修正了当前主流程里最容易让人困惑的一点：

- 之前点击“连接”后，控制器会立即请求远端扫描
- 如果远端尚未选择共享目录，用户体感上就像“连接失败了”
- 实际上失败的不是网络连接，而是连接后顺带发起的远端扫描

当前已改为：

- 连接成功与否，不再由“远端是否已选目录”决定
- 即使远端还没选目录，连接也会成功建立
- 此时首页会进入“已连接，但远端目录未就绪”的状态

同时补上了远端目录状态的主动通知链路：

- 监听端在收到握手时，会记录当前对端会话
- 已连接状态下，若本机目录发生变化，会尽量把“目录已就绪 / 未就绪”主动通知给对端
- 对端收到该通知后，会把远端目录状态更新到本地

这一步的直接目标是让主流程更符合真实使用预期：

- 连接是连接
- 选目录是选目录
- 远端稍后选好目录后，本机不需要再重新点击连接

随后又继续收了一轮首页提示语义：

- “远端目录”状态不再一律写成“已加载索引 / 未加载索引”
- 现在会区分：
  - 尚未连接
  - 已连接但远端还没选目录
  - 远端目录已就绪，正在同步索引
  - 远端索引已可用
- 预览区也去掉了与正式远端流程无关的“本地调试目标未选择”提示噪音

这样做的目的，是避免正式主流程继续被开发期遗留概念干扰。

又补了一层对称前置条件提示：

- 如果远端已经就绪，但本地源目录还没选
  - 首页会明确提示“现在只差本地源目录”
- 如果本地源目录已经就绪，但远端还没选目录
  - 首页会明确提示“现在只差远端共享目录”

这样首页不再只会笼统地说“等待自动分析”，而是能直接指出当前缺的是哪一侧。

首页的按钮层级也继续做了一轮收口：

- 连接输入与连接按钮仍保留在主流程正面区域
- 监听开关、最近地址、发现设备这些“辅助连接”能力被收进折叠区
- 刷新远端索引被保留，但降级为次要操作，并补了使用时机提示

这样页面第一眼更聚焦于：

- 连接远端
- 选择本地目录
- 等待自动预览
- 执行同步

随后首页首屏又完成了一次更彻底的步骤一重构：

- 删除了顶部的“模式 / 当前方向 / 当前流程”三张说明卡
- 步骤一改为更紧凑的连接主控区
- 当前实现包含：
  - 连接状态胶囊
  - 监听端口胶囊
  - 分享按钮
  - 地址输入框
  - 右侧连接按钮
- 最近地址被保留在输入框下方
- 二维码分享弹窗已接入，便于另一台设备扫码或手动录入地址
- 监听相关操作不再以大段说明和折叠菜单占据首屏

这一步的目标是让首页第一屏更接近真正的工具产品，而不是开发期工作台。

随后又继续做了一轮步骤一细化：

- 状态胶囊已按语义分色
  - 未监听：警示色
  - 监听中：激活色
  - 已连接：成功色
- 颜色实现基于 `ColorScheme` 语义槽位，而不是硬编码品牌色
  - 这样后续如果整体切到 Material Design 配色，组件可以直接跟随主题
- 地址输入与连接按钮已调整为上下结构
  - 连接按钮横跨整行
  - 当已经连接时，按钮会切换为“停止连接”
- “刷新远端索引”已从步骤一移到步骤三，更符合当前心智顺序
- `localhost` 设备名问题也做了一轮兜底修正，尽量回退到更可识别的平台名

随后又补了一轮更接近 Material 语义的颜色与状态控制：

- 步骤一不再只是“改胶囊颜色”，而是整块按 `ColorScheme` 语义收口
  - 连接区内部背景：`surfaceContainerLow`
  - 空闲态胶囊：中性容器色
  - 监听 / 连接中胶囊：激活容器色
  - 已连接胶囊：成功语义的 `tertiaryContainer`
  - 主连接按钮：未连接时走 `primary`，可停止时切到次级容器色
- `连接中` 不再把连接按钮彻底锁死
  - 现在连接中也可以点击“停止连接”
  - 控制器增加了连接尝试代次，避免取消后旧连接结果再把状态写回来

这样既能改善当前交互，也更利于后续整体切到更规范的 Material Design 配色体系。

随后又继续做了一轮连接区去噪与直达操作：

- 步骤一不再显示远端根目录、索引时间、文件数这些细节
- “远端共享目录已就绪”提示被收短，不再夹带额外动作说明
- 最近地址现在改为点击即连，不再只是把地址回填到输入框

这一步的目标是让步骤一继续只承担“连接与进入同步流程”的职责，不去提前展示更适合步骤三的信息。

这一步的目标很明确：

- 缩短从“打开 App”到“拿到可执行预览”的点击路径
- 避免用户必须靠失败提示倒推自己漏了哪一步
- 让当前 UI 更符合第一版的真实产品边界：`本机 -> 远端`

步骤 1 当前已可视为收口完成，最终状态如下：

- 步骤 1 现在只承担“建立连接入口”的职责
  - 不再展示远端根目录、索引时间、文件数等属于后续步骤的信息
  - 首屏重点只保留：连接状态、监听端口、分享地址、地址输入与连接按钮
- 连接与远端目录状态已彻底解耦
  - 连接成功不再依赖远端是否已选择共享目录
  - 远端稍后选好目录后，可通过现有会话把“目录已就绪”状态推送给本机
  - 本机不需要再重新点击连接
- 连接主控区已按 Material 语义收口
  - 连接状态胶囊、监听端口胶囊、分享按钮、主连接按钮都已统一走 `ColorScheme`
  - 主按钮在“可连接”和“可停止连接”之间切换
  - 连接中也允许主动停止，避免用户被卡死在等待态
- 分享地址弹窗已完成第一版产品化
  - 已改为紧凑的 `Dialog`
  - 标题改为“分享地址”
  - 二维码与地址卡片居中
  - 地址使用更接近 Material 化 code block 的样式
  - 点击地址区域即可复制
  - 分享地址现在始终以“本机监听地址 + 监听端口”为准，不再误显示对端地址
- 辅助连接入口已继续简化
  - 最近地址点击后直接尝试连接
  - 自动发现到的局域网设备会自动过期清理，避免断开后长期残留
- 当前实现下与步骤 1 直接相关的小风险已处理
  - 分享按钮在未准备好监听地址时不会误导用户
  - 状态胶囊已补齐 disabled 态，避免视觉上仍像可点击的活跃控件

因此，后续如果没有新的交互方向变化，步骤 1 不应再单独返工；只需在未来统一主题或整体视觉升级时顺带微调。

步骤 2 当前也已进入收口阶段，最近一轮已完成以下调整：

- 步骤 2 主体已从“说明 + 按钮”收为“源目录状态卡片”
  - 当前目录名作为主信息
  - 路径降级为辅助信息
  - 主操作只保留“选择目录”
  - “清除当前选择”已移到卡片右上角的轻量图标按钮
- “清理未完成传输残留”已改为按需显示
  - 只有检测到 `*.music_sync_tmp` 时才出现
  - 清理成功后会自动从卡片中收回
- 最近目录与最近地址都已补充统一的管理弹窗
  - 首页仍只保留轻量快捷入口
  - 点击管理按钮后可进入独立弹窗管理
  - 当前支持：拖拽排序、备注、删除
  - 最近地址的编辑已升级为“地址 + 备注”双字段编辑
- 最近记录的展示规则已统一
  - 无备注时：首页快捷入口与管理弹窗中都只显示主标题一行
  - 有备注时：主标题显示备注，副标题显示原始地址或目录信息
- 最近记录管理的交互样式已继续收口
  - 卡片整块可点击直接使用
  - 左侧为拖拽手柄
  - 编辑 / 删除操作与标题区域同列显示
  - 拖拽中的代理背景已恢复为透明，不再出现额外白底或过重阴影

当前判断是：步骤 2 的产品形态已经基本稳定，后续只需要处理少量观感微调与命名清理，不应再继续扩大交互范围。

## 27. 步骤 3 / 步骤 4 合并收口

首页主流程最近又做了一次结构收口：

- 原本分开的“步骤 3：差异预览”和“步骤 4：执行同步”已并为同一张工作卡片
- 卡片内部顺序现在固定为：
  - 自动分析状态
  - 远端索引手动刷新
  - 预览摘要
  - 差异列表与类型筛选
  - 执行状态与进度
  - 执行 / 停止 / 查看结果
- “计划项”不再作为独立区块悬在执行区之外，而是直接作为同一上下文内的差异明细

这样调整的原因很直接：

- 对当前产品来说，“看差异”和“立即同步”本来就是同一决策动作
- 单独拆出一个步骤 4 只会重复展示上下文，增加页面纵向噪音
- 合并后更接近真实心智模型：准备好目录后，用户只需要在一处完成检查和执行

同时，这轮还顺手清理了几类遗留问题：

- 步骤 1 中不再显示“远端共享目录已就绪 / 未就绪”这类过细的动态提示文案
- 步骤 1 与步骤 2 的最近记录编辑入口已统一成更一致的 Material 对话框样式
- 一批已经脱离正式流程的旧文案键与命名已开始收口，避免后续维护时继续把首页误当成多页调试流的拼接产物

截至当前阶段，可以把首页正式理解为三段主流程：

- 步骤 1：连接远端设备
- 步骤 2：选择本地源目录
- 步骤 3：检查并同步

后续除非同步策略本身发生变化，否则首页主流程不应再拆回四段。

## 28. 步骤 3 近期收口

最近一轮首页工作主要集中在步骤 3“检查并同步”的信息密度和交互一致性上。

已完成的调整包括：

- 预览空态和有内容态被拆开处理
  - 没有计划项时，不再提前展示摘要卡和列表控制项
  - 当前只显示居中的等待或空结果提示
  - 有计划项后，才显示筛选区、列表区和执行区
- 传输方向提示已从“局域网预览 / 本地调试预览”改为真实设备方向
  - 当前显示为 `传输方向：设备 A -> 设备 B`
  - 本机设备名沿用连接层已有的主机名兜底逻辑
  - 远端设备名直接来自当前连接会话
- 执行区已进一步压缩
  - 主按钮当前采用 `开始同步 / 停止同步` 单按钮切换
  - 独立停止按钮已移除
  - 执行状态、进度条、文件进度和当前文件被收进更紧凑的单块信息面板
- 列表筛选能力已重做为“本地前端筛选”
  - 不再因为切换筛选就重建远端预览
  - 底层预览始终保留全量结果，页面只负责显示过滤

筛选交互当前状态如下：

- `项目类型`
  - 支持 `全部项目 / 复制项 / 删除项 / 冲突项`
  - `全部项目` 已调整为独立总览态
  - 它不会再视觉上把三类具体项一并勾上
  - 点击具体项后，会自动退出 `全部项目`
- `文件类型`
  - 支持多选
  - `全部类型` 为特殊总览态
  - 选择具体后缀后，会自动退出 `全部类型`
  - 所有具体后缀取消后，会自动回到 `全部类型`

列表表现也做了一轮收口：

- 列表容器新增边框和背景，和外部卡片形成明确分层
- 单项自身也有轻量边界，避免内容直接漂浮在列表区域里
- 右侧差异徽标已完成 i18n 化，不再直接显示硬编码英文
- 即使当前筛选无条目，列表容器仍然保留，只在容器内部显示“当前筛选无条目”

这轮调整的目的不是继续叠功能，而是把步骤 3 从“技术上可用”进一步收口到“产品上可读、可筛、可执行”。

## 29. 忽略后缀规则

设置页最近新增了一组正式规则配置：

- `忽略后缀`

当前实现方式是：

- 设置页显示摘要
  - 无规则时显示“当前没有忽略任何后缀”
  - 有规则时显示已忽略的后缀数量
- 点击后进入独立管理弹窗
  - 可添加后缀
  - 可删除后缀
  - 保存后持久化到本地设置存储

更重要的是，这组规则当前已经接入正式预览构建链路：

- 被忽略的后缀不会进入预览构建
- 也不会进入同步计划
- 因此它不是页面级的临时筛选，而是全局生效的同步规则

为了降低理解成本，步骤 3 当前也已补上轻量提示：

- 在“文件类型”标题右侧显示 `已忽略：.x, .x`
- 只有当设置中真的存在忽略规则时才显示

这使“全局忽略规则”和“当前页面临时筛选”终于被分层表达：

- 设置页的忽略后缀：决定哪些文件根本不进入计划
- 步骤 3 的文件类型筛选：只决定当前计划怎样显示

## 30. 设置页与错误模型收尾

这一轮又补了两类收尾工作：

- 设置页结构继续规范化
  - 返回按钮已并入标题左侧，和页面标题形成一行头部
  - `常规` 分组标题已轻微右移，和内容卡片对齐得更自然
  - 设置页的 joined card 组件已抽到 `features/settings/presentation/widgets/settings_group.dart`
  - 后续新增设置项时，只需要继续往 `SettingsJoinedGroup` 中追加 `SettingsActionRow`
- 错误文案从状态层继续抽离
  - `connection / directory / preview / execution` 这四个 state 不再直接保存中文用户文案
  - 当前先统一输出标准错误键或清洗后的兜底文本
  - 页面层通过 `AppErrorLocalizer` 再映射到 `l10n`
  - 这样英文界面不会再因为状态层硬编码而混入中文

本轮之后，设置页和错误模型都更接近可持续扩展的正式结构，而不是临时拼接状态。

## 31. 命名与目录收口

按“只修不规范或语义不清项”的原则，本轮做了轻量重排：

- 文件命名语义增强
  - `lib/l10n/app_localizations_x.dart` 已重命名为 `lib/l10n/app_localizations_ext.dart`
  - 原文件名中的 `x` 语义过弱，不利于长期维护时快速理解用途
- 测试目录层级统一
  - `test/protocol_codec_test.dart` 已移动到 `test/unit/network/protocol_codec_test.dart`
  - `test/widget_test.dart` 已移动并改名为 `test/widget/app_boot_test.dart`
  - 现在测试目录结构更一致：`unit` 放逻辑测试，`widget` 放界面测试
- 导入路径统一
  - 所有 `app_localizations_x.dart` 导入已同步替换为 `app_localizations_ext.dart`

这次没有做全项目命名风格迁移，仅收口了当前明显不规范或语义不清的项，避免引入不必要的重命名噪音。

## 32. 设置页结构化收尾

这一轮把设置页做了最终的结构化整理，重点是减少散落配置并提高后续可维护性：

- 间距尺度继续收口
  - 页面与弹窗中的常用间距已统一为常量（`S/M/L`），减少硬编码数值分散
  - 现在调整设置页密度时，只需要改顶部常量，不需要在控件树里逐个查找
- 交互细节抽离
  - 开关拇指图标状态逻辑已提取为私有方法，避免主 build 逻辑继续膨胀
  - `Switch` 已支持选中 `check`、未选中 `close` 的图标语义
- 主题化一致性
  - `Switch` 的轨道/拇指颜色已统一走 `app_theme.dart` 中的 `switchTheme`
  - 页面局部只保留行为级配置，不再重复做视觉配色判断

至此，设置页已经进入“可持续迭代”状态：新增配置项可直接复用既有行组件和间距体系，不需要再做结构性重构。

## 33. 设置文案与忽略类型弹窗规范化

这一轮继续收口了设置页的两个细节：

- 文案中英同步
  - 你更新了中文后，英文文案已同步到同一语义：
    - `自动监听 / Auto Listening`
    - `忽略文件类型 / Ignored File Types`
  - 避免出现中英文语义不一致导致的后续评审反复
- 忽略文件类型弹窗结构规范化
  - 从自定义 `Dialog + 手工底部按钮区` 收口为更标准的 `AlertDialog` 结构
  - 标题 / 内容 / 操作按钮分区更明确
  - 内容区仍保留输入、列表、删除等原有能力
  - 间距继续复用设置页既有尺度常量，避免新增散落 hardcode

这一步主要提升的是一致性和可维护性，不改变既有业务逻辑。

## 34. 设置页新增外观分组

设置页本轮新增了 `外观` 分组，并补齐了可持久化的主题偏好配置：

- 新增分组与条目
  - `主题模式`：浅色 / 深色 / 跟随系统
  - `调色板`：Neutral / Expressive / Tonal Spot
  - 两个条目都通过 `settings_dialog_shell` 打开选择弹窗
- 状态与存储
  - `SettingsState` 新增 `themeMode` 与 `palette`
  - `SettingsStore` 新增对应读写键并持久化到 `SharedPreferences`
  - `SettingsController` 新增 `setThemeMode` / `setPalette`
- 应用生效链路
  - `MusicSyncApp` 现在会读取设置并应用：
    - `themeMode` -> `ThemeMode`
    - `palette` -> `DynamicSchemeVariant`
  - `AppTheme` 新增 `dark(...)` 并支持按 palette 生成亮/暗主题

另外，这轮顺手把弹窗里的单选控件切换到了新版 `RadioGroup` 写法，清理了 Flutter 3.41 的弃用告警。

## 35. 首页步骤 3 预览区收口

这一轮没有继续扩展同步能力，而是集中收口首页步骤 3 的信息结构与交互节奏：

- 顶部状态表达改为“标签 + 胶囊值”
  - `传输方向`：胶囊中只显示 `A -> B`
  - `目录状态`：胶囊中显示 `本地 | 远端` 两段状态，并通过图标直接表达是否就绪
- 之前独立的一句等待文案已移除
  - 不再额外占据一行说明文字
  - 目录是否准备好，统一由 `目录状态` 胶囊承担表达
- 预览与执行动作进一步并拢
  - `开始同步 / 停止同步`
  - `生成远端预览`
  - `查看结果`
  - 执行进度也回收到同一操作区下方，而不是单独占一张远离的状态卡
- 计划列表进一步分层
  - 主列表只承载可执行项（复制 / 删除）
  - 冲突项从主筛选体系中独立出去，作为单独的冲突提示区长期显示
  - 即使当前切换到 `全部类型 / 复制项 / 删除项`，冲突提示也不会被隐藏

这个阶段的目标不是继续增加功能，而是把首页主线稳定成：

- 建立连接
- 选择目录
- 自动分析 / 手动生成预览
- 直接开始同步

也就是说，首页正在从“功能工作台”继续收口为“可发布的第一版主流程”。

## 36. 冲突展示与后续媒体判定方向

当前冲突判定逻辑仍然保持最小实现：

- 在 `diff_engine.dart` 中
- 同路径文件双方都存在
- 只要 `size` 或 `modifiedTime` 不一致
- 就标记为 `conflict`
- 当前原因固定为 `metadata_mismatch`

这一轮没有继续把冲突系统扩展到音乐元数据层，而是先做了展示优化：

- 冲突列表的右侧徽标不再仅显示“冲突”
- 现在会直接显示原因的人类可读文案
  - 当前已接入：`metadata_mismatch -> 元数据不同`
- 列表正文不再把底层英文 reason 拼接到文件名后方
  - 这样在窄屏和手机上更容易读清文件名本身

同时，已确认一个后续高价值但暂缓进入第二个 commit 的方向：

- 音乐文件冲突不应只看文件大小与修改时间
- 更有价值的是引入：
  - 标签完整度（标题、歌手、专辑、歌词、封面等）
  - 音质信息（码率、采样率、位深、编码格式等）

这部分需求已经记录，但当前为了尽快完成第二个稳定 commit，不在本轮实现。

## 37. 代码格式化与静态检查约定

项目当前不引入 `Prettier`。Flutter / Dart 工程统一使用官方工具链：

- 格式化：`dart format`
- 静态检查：`flutter analyze`
- 可选自动修复：`dart fix`

同时，工作区已补充编辑器设置：

- `.vscode/settings.json`
  - Dart 文件保存时自动格式化
  - 默认 formatter 指向 Dart 官方扩展
  - 保存时显式执行 import 整理
  - 行宽按 `100` 列显示辅助线

当前策略是“保持官方默认，不引入激进 lint”：

- `analysis_options.yaml` 继续基于 `flutter_lints`
- 仅追加少量项目级规则
- 避免在当前阶段因为一次 lint 收紧而引爆大量历史改动

因此，后续默认提交前检查约定为：

- `dart format lib test`
- `flutter analyze`

## 38. 进度记录

详细的页面演进、阶段收口和近期稳定性补强已拆分到：

- [开发进度记录](E:\System\Documents\GitHub\MusicSync\docs\progress-log.md)

当前建议使用方式：

- `implementation-plan.md`
  - 保留总目标、架构、模块边界、核心设计与当前路线
- `progress-log.md`
  - 记录按轮次推进的产品调整、页面收口、稳定性补强与最近完成项

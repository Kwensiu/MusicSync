# 传输链路重构代码级方案

本文档定义 MusicSync 当前远程文件复制链路的重构方案。目标是：在尽量保留现有设备发现、连接、扫描、预览、删除等控制面逻辑的前提下，把文件内容传输从“多次 JSON + base64 分块 RPC”改为“单请求二进制流上传”，显著提升大文件与混合文件场景下的传输吞吐。

## 1. 现状结论

当前远程复制链路为：

1. 调用 `beginCopy`
2. 调用端通过 `FileAccessGateway.openRead()` 读取本地文件流
3. 每读取一个 chunk，就调用一次 `writeChunk`
4. `writeChunk` 将 chunk 做 `base64Encode` 后包进 JSON 请求体
5. 服务端完整读取 JSON body，解析后再 `base64Decode`
6. 服务端把解码后的字节写入临时文件
7. 文件传完后调用 `finishCopy`

关键位置：

- `lib/services/sync/remote_sync_executor.dart`
- `lib/services/network/http/http_sync_client.dart`
- `lib/services/network/http/http_sync_server_service.dart`
- `lib/features/connection/state/connection_controller.dart`

该方案的主要性能问题：

- 每个 chunk 都是一次独立 HTTP 请求，存在明显的请求往返开销
- 每个 chunk 都经过 JSON 序列化和 base64 膨胀，网络体积增加约 33%
- 服务端按字符串方式整包读取请求体，不是二进制流式处理
- Android 写入链路还会再走一次 MethodChannel 调用，额外放大每块传输成本
- 当前发送侧严格串行等待每个 chunk 的响应，不具备流水线特征

因此，当前约 3 MB/s 的吞吐更像协议设计瓶颈，而不是发现机制或纯网络带宽上限。

## 2. 设计目标

本次重构的目标限定如下：

- 保留现有基于 UDP 的设备发现机制
- 保留现有 `hello`、`directoryStatus`、`scan`、`entryDetail`、`deleteEntry` 等 HTTP 控制接口
- 仅替换“文件内容复制”这一段协议
- 保留现有临时文件写入与完成后 rename 的安全语义
- 保留现有取消传输、失败清理、进度上报的能力
- 优先做最直接、可验证、可渐进落地的方案，不顺带做多文件并发调度

非目标：

- 不在第一阶段引入多文件并发上传
- 不在第一阶段引入断点续传
- 不在第一阶段重写设备连接模型
- 不在第一阶段调整扫描和预览的业务语义

## 3. 方案结论

第一阶段采用：

- 新增单文件单请求的二进制流上传接口
- 请求元数据通过请求头传输
- 请求体直接承载文件原始字节流
- 服务端对该接口直接以流式方式写入临时文件
- 成功后 rename 临时文件，失败或中断则清理临时文件

本轮收口后，远程复制流程中的旧接口已移除：

- `beginCopy`
- `writeChunk`
- `finishCopy`
- `abortCopy`

由单请求上传接口自行负责：

- 校验参数
- 创建目标目录
- 创建临时文件
- 流式写入
- 成功完成后 rename
- 失败时删除临时文件

这样可以避免“先 begin 再 stream 再 finish”造成的会话状态分散。

## 3.2 实施状态

当前代码状态已收口到单协议实现：

- 发送侧固定走 `copyFileStream`（`stream-v1`）
- 接收侧固定通过 `copyFileStream` 路由处理文件写入
- 旧 `begin/write/finish/abort` 协议链路与状态管理已从主流程移除
- `hello` 中仍携带 `transferProtocols`，用于连接期能力可见性和诊断日志

## 3.1 LocalSend 可参考点

基于本地 LocalSend 源码核对后，可以确认它并没有与本方案完全一致的“省略 prepare、直接单文件流上传”的模式，而是更接近：

- `prepare-upload`：先提交整个会话的文件元数据
- `upload`：每个文件再走一次二进制 body 上传
- `cancel`：显式取消当前发送或接收会话

已核实的实现点：

- 发送端上传使用 `postStream(...)`，请求体是流式二进制数据，头里带 `Content-Length` / `Content-Type`
- 上传路由通过 query 传 `sessionId`、`fileId`、`token`
- 接收端 `_uploadHandler(...)` 直接把 `HttpRequest` 作为字节流传给 `saveFile(...)`
- 接收端存在显式 `cancel` 路由，但代码里也明确写了 TODO：当前并不能真正中断已经在途的 incoming request
- 接收端默认不是“临时文件完成后 rename”，而是直接写最终目标路径；如果重名，则自动追加计数后缀
- 接收端对嵌套路径做了 path traversal 校验，防止越出目标目录

对 MusicSync 有价值的借鉴：

- 文件内容直接走单请求二进制流，而不是 JSON + base64 分块 RPC
- 传输前先把会话级元数据和文件级内容传输分开思考
- 路径合法性、命名冲突、取消语义需要在方案里明确写死
- 若需要会话级取消，协议上最好有显式 cancel 通道，而不是只依赖断连接

不直接照搬的部分：

- LocalSend 的主模型是“prepare-upload + upload + cancel”的多文件会话
- LocalSend 默认采用“重名自动改名”，而 MusicSync 当前目标更接近镜像同步语义，优先应保持覆盖语义
- LocalSend 当前没有把“取消已进入的 HTTP 上传”彻底做实，因此它更适合作为边界提醒，而不是现成答案

## 4. 新协议设计

### 4.1 新增路由

在 `lib/services/network/http/http_sync_routes.dart` 新增文件上传路由，例如：

- `copyFileStream`

建议路径：

```dart
static const String copyFileStream = '/copy-file-stream';
```

命名原则：

- 保持与当前路由风格一致
- 明确表示该接口承载的是单次文件流上传，而不是分块 RPC

### 4.2 请求方法

建议使用：

- `POST /copy-file-stream`

理由：

- 与当前项目其它写操作接口风格一致
- 不强制引入幂等语义要求
- 便于复用现有控制器中的“执行一个复制动作”理解方式

### 4.3 请求头

请求头承载元数据，建议如下：

- `content-type: application/octet-stream`
- `x-remote-root-id`
- `x-relative-path`
- `x-file-size`

可选附加头：

- `x-transfer-id`

第一阶段建议只把真正必要的信息放进头部：

- `x-remote-root-id`
- `x-relative-path`
- `x-file-size`

`transferId` 在单请求模型下不是必须，可以移除。

需要注意：

- `relativePath` 不建议直接把原始字符串裸放进 header
- 因为路径段可能包含中文、空格和特殊字符，直接放 header 存在兼容性风险

第一阶段建议：

- `x-relative-path` 使用 UTF-8 后再做 URL-safe 编码
- 服务端读取后先解码，再进入路径校验和目录创建逻辑

`x-file-size` 建议作为必填字段，而不是可选字段。原因：

- 服务端可校验实际接收字节数是否完整
- 更容易区分“中断导致半文件”与“正常完成”
- 为吞吐统计、日志和后续诊断提供稳定依据

### 4.4 请求体

请求体为原始字节流：

- 不做 JSON 包装
- 不做 base64
- 不做每块确认应答

发送端直接把 `FileAccessGateway.openRead(entryId)` 返回的流写入 `HttpClientRequest`。

### 4.5 响应体

成功时返回简单 JSON：

```json
{ "ok": true }
```

失败时延续当前服务端风格：

```json
{ "message": "..." }
```

这样可以复用 `HttpSyncClient` 里现有的错误读取逻辑。

## 5. 分层改造方案

## 5.1 DTO 与路由层

涉及文件：

- `lib/services/network/http/http_sync_routes.dart`
- `lib/services/network/http/http_sync_dto.dart`

建议改动：

1. 在 routes 中新增 `copyFileStream`
2. 在 `hello` 响应中新增能力字段，例如：
   - `transferProtocols: ['chunk-rpc', 'stream-v1']`
3. 不为文件字节流上传新增 JSON DTO
4. 将以下 DTO 标记为待废弃，并在迁移完成后删除：
   - `BeginCopyRequestDto`
   - `WriteChunkRequestDto`
   - `FinishCopyRequestDto`
   - `AbortCopyRequestDto`

原因：

- 新接口元数据在请求头，不再需要为流上传定义 body DTO
- 旧 DTO 只服务于旧的 chunk RPC 模式
- 能力字段用于新旧协议协商，避免升级过程中的兼容问题

## 5.2 HTTP Client 层

涉及文件：

- `lib/services/network/http/http_sync_client.dart`

### 新增方法

新增一个用于单文件流上传的方法，例如：

```dart
Future<void> copyFileStream({
  required String address,
  required int port,
  required String remoteRootId,
  required String relativePath,
  required int expectedBytes,
  required Stream<List<int>> source,
  required bool httpEncryptionEnabled,
})
```

### 方法职责

该方法内部负责：

1. 调用 `_post()` 创建请求
2. 将 `contentType` 改为 `application/octet-stream`
3. 设置 `x-remote-root-id`、`x-relative-path`、`x-file-size` 请求头
4. 将 `source` 中的字节流持续写入 request
5. 关闭请求并等待响应
6. 若响应为非 2xx，则抛出与现有逻辑一致的 `HttpException`

### 方法实现约束

- 不要把整个文件读入内存
- 不要把流重新拼成 `List<int>` 后一次性发送
- 不要再做 base64
- 不要在 client 层手动维护 begin / finish / abort 状态机

### 保留的已有能力

保留：

- `_post()`
- `_drainSuccessResponse()`
- `_throwIfErrorResponse()`
- `_buildUri()`

仅在新上传方法中覆写请求头和 body 写入方式即可。

### 旧方法处理

以下方法已从 `HttpSyncClient` 中删除：

- `beginCopy`
- `writeChunk`
- `finishCopy`
- `abortCopy`

## 5.3 同步执行层

涉及文件：

- `lib/services/sync/remote_sync_executor.dart`

### 当前问题

改造前复制逻辑是：

- 生成 `transferId`
- `beginCopy`
- `await for chunk in openRead()`
- 每块 `writeChunk`
- `finishCopy`
- 失败则 `abortCopy`

这会把文件上传变成严格串行的分块 RPC。

### 重构后逻辑

改为：

1. 对每个待复制文件直接调用 `copyFileStream`
2. `source` 由 `openRead(sourceEntryId)` 提供
3. 进度统计仍在发送端读取流时进行
4. 若发生异常，保留当前失败计数、`lastError` 记录和继续后续文件的语义
5. 不再保留旧协议回退分支

### 关键难点：进度上报

当前进度是在每个 chunk 成功写远端后更新：

- `processedBytes += chunk.length`
- `onProgress(...)`

新模型中仍需要保留进度，但不能破坏流式发送。

建议做法：

- 在 `RemoteSyncExecutor` 内部包一层进度流转换器
- 对 `openRead()` 返回的 `Stream<List<int>>` 做 `map` 或 `transform`
- 每次产出 chunk 时先累计 `processedBytes` 并回调 `onProgress`
- 再把原始 chunk 原样交给 `copyFileStream`

示意：

```dart
final Stream<List<int>> source = _fileAccessGateway
    .openRead(sourceEntryId)
    .map((List<int> chunk) {
      processedBytes += chunk.length;
      onProgress(...);
      return chunk;
    });
```

注意：

- 这里的进度表示“字节已从本地读取并提交到 HTTP 请求流”
- 它不再是“每块已收到服务端单独 ack”
- 但在单请求流上传模型中，这个语义是合理且常见的
- 单个文件只有在服务端返回 2xx 后，才应计为真正复制成功

### 取消语义

新模型建议：

- 在 `copyFileStream` 过程中若 `cancelToken` 被触发，主动终止上传流程
- 终止后由服务端在请求中断、异常或未成功完成时删除临时文件

这里需要进一步明确实现要求：

- 不能只在读取下一个 chunk 前检查 `cancelToken`
- 还需要让客户端能主动中断当前 `HttpClientRequest` 或其底层连接写入
- 中断后应继续向上层抛出 `SyncCancelledException`
- 服务端应把“请求流提前结束”视为失败路径，而不是正常完成

清理由服务端上传 handler 的 `try / catch / finally` 保证。

## 5.4 服务端 HTTP 层

涉及文件：

- `lib/services/network/http/http_sync_server_service.dart`

### 新增 handler typedef

新增文件流上传 handler，例如：

```dart
typedef CopyFileStreamHandler = Future<void> Function(
  HttpRequest request,
  String remoteRootId,
  String relativePath,
);
```

或者更收敛一些：

```dart
typedef CopyFileStreamHandler = Future<void> Function(HttpRequest request);
```

但第一种更清晰，因为参数解析留在 server service 层，业务 handler 只关心业务字段和请求流。

### `start()` 参数扩展

在 `start()` 中新增：

- `required CopyFileStreamHandler onCopyFileStream`

并在 `_handleRequest()` 中新增路由分支：

- `POST ${HttpSyncRoutes.copyFileStream}`

### 该分支的处理方式

与其它 JSON 接口不同，这个分支不能调用 `_readJsonBody()`。

建议逻辑：

1. 从 headers 读取 `x-remote-root-id`
2. 从 headers 读取 `x-relative-path`
3. 从 headers 读取 `x-file-size`
4. 对路径做解码与合法性校验
5. 校验字段非空
6. 调用 `onCopyFileStream(request, remoteRootId, relativePath)`
5. 业务 handler 成功后返回 `{ok: true}`

### 新增辅助方法

可以在 server service 内新增一个 header 读取助手，例如：

```dart
String _requireHeader(HttpHeaders headers, String name)
```

用于：

- 统一读取头部
- 缺失时抛 `FormatException`

还建议新增：

- `_decodeRelativePathHeader(...)`
- `_requireIntHeader(...)`

用于统一处理路径解码和字节数解析。

### 现有 JSON body 方法保持不变

- `_readJsonBody()` 继续给控制面接口用
- 文件上传接口单独旁路处理

## 5.5 连接控制器服务端落盘逻辑

涉及文件：

- `lib/features/connection/state/connection_controller.dart`

当前负责文件接收的逻辑分散在：

- `_handleHttpCopyFileStream(...)`

### 重构方向

将其收敛为一个新的上传处理入口，例如：

- `_handleHttpCopyFileStream(HttpRequest request, String remoteRootId, String relativePath)`

### 新 handler 职责

1. 调用 `_setIncomingSyncActive(true)`
2. 校验参数
3. 调用 `_ensureRemoteParentDirectory(...)`
4. 创建临时文件写入 session
5. 解析临时文件 entryId
6. 对 `request` 执行流式写入，并统计实际接收字节数
7. 校验实际接收字节数与 `x-file-size` 一致
8. 成功时关闭 session，并 rename 为最终文件名
9. 失败或中断时关闭 session，并删除临时文件
10. 最终根据是否仍有其它入站任务，恢复 `isIncomingSyncActive`

### 建议拆分出的辅助方法

为了避免新方法过长，建议新增少量私有方法：

- `_createIncomingTempWrite(...)`
- `_pipeIncomingRequestToSession(...)`
- `_finalizeIncomingTempFile(...)`
- `_cleanupIncomingTempFile(...)`
- `_resolveFinalNameConflict(...)`

但不要为了单一场景再造额外抽象层，辅助方法只服务于这一路径即可。

### 会话状态是否保留

已删除 `_incomingWriteSessions`、`_incomingWriteTargets` 及 transferId 相关接收态管理。

### `isIncomingSyncActive` 的处理

当前已经存在 `syncSessionState` 控制接口，用于表达“远端同步会话是否正在进行”。因此一阶段建议区分两层语义：

- `syncSessionState` 负责会话级“正在接收远端同步”状态
- `copyFileStream` handler 只负责单文件上传落盘，不主动重置整个会话状态

原因：

- 远端同步通常由多个文件串行组成
- 如果把 `isIncomingSyncActive` 直接绑定到单文件 handler 的开始/结束，UI 可能在文件间隙闪烁

因此当前不建议把全局接收态完全转移到单文件上传 handler 上。

## 5.6 文件访问层

涉及文件：

- `lib/services/file_access/file_access_gateway.dart`
- `lib/services/file_access/windows_file_access_gateway.dart`
- `lib/services/file_access/android_file_access_gateway.dart`

### Windows

Windows 侧当前写入实现已经可以持续写块：

- `IOSink.add(chunk)`

因此第一阶段不需要为了新网络协议改接口。

### Android

Android 侧当前 `FileWriteSession.write()` 仍会把 chunk 再做一次 base64 后通过 MethodChannel 发送。

第一阶段建议：

- 先不改 `FileAccessGateway` 抽象
- 保持 `session.write(List<int> chunk)` 现有接口
- 先让网络层去掉 JSON + base64 + 多请求往返

原因：

- 光是把网络层从 chunk RPC 改成单请求二进制流，收益已经很大
- Android MethodChannel 侧可作为第二阶段单独优化

### Android 第二阶段建议

后续可再评估：

- `MethodChannel` 直接传 `Uint8List`
- 原生侧直接写字节，去掉二次 base64

但不纳入本文档的一阶段落地范围。

## 6. 代码级实施步骤

建议按以下顺序落地。

### 第 1 步：新增上传路由

修改：

- `lib/services/network/http/http_sync_routes.dart`

新增：

- `copyFileStream`

### 第 2 步：扩展服务端 HTTP 分发

修改：

- `lib/services/network/http/http_sync_server_service.dart`

新增：

- `CopyFileStreamHandler` typedef
- `start()` 的 `onCopyFileStream` 参数
- `_handleRequest()` 中的上传路由分支
- 读取 header 的私有辅助方法

### 第 3 步：在客户端新增流上传方法

修改：

- `lib/services/network/http/http_sync_client.dart`

新增：

- `copyFileStream(...)`

要求：

- 直接写入二进制 body
- 保持当前错误处理风格

### 第 4 步：在连接控制器接入新服务端 handler

修改：

- `lib/features/connection/state/connection_controller.dart`

改动：

- `startListening()` 里把 `onCopyFileStream` 传给 server
- 新增 `_handleHttpCopyFileStream(...)`
- 新增临时文件写入和清理辅助方法

### 第 5 步：切换同步执行器到新客户端方法

修改：

- `lib/services/sync/remote_sync_executor.dart`

改动：

- 删除 `transferId` 生成与使用
- 删除 `beginCopy / writeChunk / finishCopy / abortCopy` 调用链
- 调用新的 `copyFileStream(...)`
- 保留并调整进度上报

### 第 6 步：清理旧协议残留（已完成）

修改：

- `lib/services/network/http/http_sync_dto.dart`
- `lib/services/network/http/http_sync_client.dart`
- `lib/services/network/http/http_sync_server_service.dart`
- `lib/features/connection/state/connection_controller.dart`
- 相关测试文件

已删除：

- 旧的分块复制 DTO
- 旧的 begin/write/finish/abort handler 和状态
- 不再使用的辅助方法和字段

## 7. 关键实现细节要求

### 7.1 服务端必须使用临时文件

新上传接口仍必须保持：

- 先写入 `$fileName${AppConstants.tempFileSuffix}`
- 上传完整成功后再 rename 成最终文件名

原因：

- 避免上传中断时留下半文件并污染目标目录
- 兼容现有的失败清理思路

### 7.2 服务端必须在异常路径清理临时文件

以下场景都必须删除临时文件：

- 请求头缺失或非法
- 目标目录创建失败
- 请求中途断开
- `session.write()` 抛错
- `session.close()` 抛错
- rename 失败

不能依赖客户端额外接口做清理。

还应把“请求体提前结束且接收字节数小于 `x-file-size`”视为失败路径，并删除临时文件。

### 7.3 发送端不要预先缓存整个文件

新上传流程中，发送端必须保持：

- `openRead()` -> 按流读取 -> 直接写请求体

不能变成：

- 先 `toList()` 聚合所有块
- 再一次性发送

否则会把吞吐问题转化为内存问题。

### 7.4 上传接口不能走 `_readJsonBody()`

服务端上传接口必须直接消费 `HttpRequest` 字节流。

不能：

- `utf8.decoder.bind(request).join()`
- `jsonDecode(...)`

因为这会重新引入当前瓶颈。

### 7.5 错误信息风格保持一致

为了不破坏上层错误本地化和已有测试习惯：

- 服务端异常仍通过 `{message: error.toString()}` 返回
- 客户端继续通过 `_throwIfErrorResponse()` 解析报错

### 7.6 必须明确覆盖与命名冲突语义

上传成功后的目标文件处理，必须在方案里提前定死，不应留给平台实现各自发挥。

第一阶段建议保持 MusicSync 的镜像同步语义：

- 若目标文件已存在，则新上传的临时文件应覆盖旧文件
- 若底层平台不支持“rename 覆盖”，则采用“先删除旧文件，再 rename 临时文件”的受控流程

如果未来要支持“保留旧文件并自动改名”，应作为独立产品语义，不混入本次协议重构。

### 7.7 路径安全要求

`relativePath` 即使来自已连接对端，也必须在服务端再次校验：

- 不允许空段、`.`、`..`
- 不允许绝对路径
- 不允许在解码后逃逸出目标 root
- 文件名继续复用现有非法字符清理或拒绝策略

这里不能只依赖客户端正确构造请求。

### 7.8 第一阶段不做多文件并发

即使新上传接口可以支持更高吞吐，第一阶段仍建议：

- `RemoteSyncExecutor` 继续按文件串行处理

原因：

- 先验证协议收益
- 降低调试面
- 避免同时引入调度策略变化

## 8. 测试调整建议

涉及重点测试文件：

- `test/unit/network/http_sync_client_test.dart`
- `test/unit/connection/connection_controller_test.dart`
- 与远程执行相关的测试

### 需要新增的测试

1. `HttpSyncClient.copyFileStream()`
   - 能发送 `application/octet-stream`
   - 能携带 `x-remote-root-id`
   - 能携带 `x-relative-path`
   - 能携带 `x-file-size`
   - 服务端 2xx 时成功
   - 服务端非 2xx 时抛错

2. `HttpSyncServerService` 上传分发
   - 正确命中新路由
   - 缺失请求头时报错
   - 非法 `x-file-size` 时报错
   - 非法路径编码时报错
   - handler 成功时返回 `{ok: true}`

3. `ConnectionController` 上传处理
   - 能创建目标父目录
   - 能写入临时文件
   - 接收字节数不足时删除临时文件
   - 路径包含非法段时拒绝写入
   - 成功后 rename
   - 失败时删除临时文件

4. `RemoteSyncExecutor`
   - 调用新 `copyFileStream()` 而不是旧 chunk API
   - 进度累计仍正确
   - 单文件失败不影响后续文件继续处理
   - 取消时能正确停止并把错误上传到上层执行状态

5. 协议可见性
   - `hello` 请求与响应均携带 `transferProtocols`
   - 被动连接建立后也能更新能力状态（用于诊断与日志）

6. 特殊路径与文件名
   - 中文路径可正常传输
   - 空格与特殊字符路径可正常传输
   - header 编码/解码后一致

### 需要删除或重写的测试

- 与 `writeChunk` / `finishCopy` / `abortCopy` 细节强绑定的单元测试
- 对 transferId 生命周期有断言的测试

## 9. 收口说明

本方案对应代码已完成主路径收口：

- 仅保留 `stream-v1` 文件内容传输协议
- 旧 chunk RPC 协议代码已清理
- 测试已同步迁移到新协议路径

## 10. 后续事项归档

本次协议重构已经完成主路径收口。

后续仍值得继续追踪的传输相关事项，例如：

- Android `MethodChannel` 写入去 base64
- 取消时主动中断正在进行的 HTTP 上传
- 吞吐统计与诊断日志
- 小文件有限并发

统一收敛到主文档 [`implementation-plan.md`](/C:/Users/x1852/.codex/worktrees/a543/MusicSync/docs/implementation-plan.md) 的 `第一版 TODO` 中维护，不再在本方案文档里重复展开。

## 11. 本方案的边界

本方案解决的是：

- 当前远程复制吞吐低的问题
- 分块 RPC 带来的协议和编码开销
- 服务端非流式处理导致的额外损耗

本方案不解决的是：

- Android SAF / MethodChannel 本身的全部写入开销
- 多文件并发调度策略
- 目录扫描、预览加载和元数据读取性能
- 跨平台文件系统权限层面的极端慢路径

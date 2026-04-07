// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MusicSync';

  @override
  String get homeModeTitle => '模式';

  @override
  String get homeModeDescription => '通过局域网执行单向镜像同步。';

  @override
  String get homeSyncDirectionTitle => '当前方向';

  @override
  String get homeSyncDirectionDescription =>
      '第一版固定为：本机目录 -> 远端目录。监听与连接只负责建立会话，不代表复制方向。';

  @override
  String get homeLocalLibraryTitle => '本地音乐库';

  @override
  String get homeLocalSourceHint => '此目录会作为源目录，远端将向它对齐。';

  @override
  String get directoryPreflightWarningTitle => '预检提示：该目录可能较重，生成预览时可能较慢。';

  @override
  String directoryPreflightSampleSummary(
      int children, int directories, int files) {
    return '预检样本：顶层条目 $children 个，目录 $directories 个，文件 $files 个。';
  }

  @override
  String get directoryPreflightManyRootChildren => '检测到顶层条目很多，完整扫描可能较慢。';

  @override
  String get directoryPreflightDenseNestedDirectory =>
      '检测到浅层目录中已有高密度子项，完整扫描可能较慢。';

  @override
  String get directoryPreflightInaccessibleSubdirectory =>
      '检测到浅层子目录存在访问限制，预览时可能出现警告或超时。';

  @override
  String get directoryPreflightSystemLikeDirectory =>
      '该目录看起来像系统或缓存目录，不太适合作为音乐库。';

  @override
  String get homeNoDirectorySelected => '尚未选择目录。';

  @override
  String get homePickDirectory => '选择目录';

  @override
  String get homeRecentDirectories => '最近目录';

  @override
  String get homeCleanupTempFiles => '清理未完成传输残留';

  @override
  String homeCleanupTempSuccess(int count) {
    return '已清理 $count 个临时文件。';
  }

  @override
  String homeCleanupTempPartial(int deleted, int failed) {
    return '已清理 $deleted 个临时文件，另有 $failed 个条目清理失败。';
  }

  @override
  String get homeCleanupTempFailed => '清理临时文件失败，请稍后重试。';

  @override
  String get homeRecentAddresses => '最近地址';

  @override
  String get homeDiscoveredDevices => '发现到的设备';

  @override
  String get homeRemoteTargetTitle => '远端目标';

  @override
  String get homeRemoteTargetHint => '当前第一版只支持从本机同步到远端。';

  @override
  String get homeRemoteDirectoryReady => '远端共享目录已就绪，可刷新索引或直接生成远端预览。';

  @override
  String get homeRemoteDirectoryMissing =>
      '远端共享目录未就绪。请先在远端设备上选择共享目录，再刷新索引或生成远端预览。';

  @override
  String get homeListenerTitle => '监听';

  @override
  String get homeListenerStart => '开始监听';

  @override
  String get homeListenerStop => '停止监听';

  @override
  String homeListenerPort(int port) {
    return '监听端口：$port';
  }

  @override
  String get homePeerAddressLabel => '设备地址';

  @override
  String get homePeerAddressHint => '192.168.1.8:44888';

  @override
  String get homeConnect => '连接';

  @override
  String get homeDisconnect => '断开连接';

  @override
  String homeConnectionStatus(Object status) {
    return '状态：$status';
  }

  @override
  String homePeerName(Object name) {
    return '设备：$name';
  }

  @override
  String get homeRefreshRemoteIndex => '刷新远端索引';

  @override
  String homeRemoteRoot(Object name) {
    return '远端根目录：$name';
  }

  @override
  String homeRemoteFiles(int count) {
    return '远端文件数：$count';
  }

  @override
  String get homeOpenPreview => '打开预览';

  @override
  String get previewTitle => '预览';

  @override
  String get previewSummaryTitle => '摘要';

  @override
  String get previewScopeLocal => '本地调试预览：本机 -> 本地目标';

  @override
  String get previewScopeRemote => '局域网预览：本机 -> 远端';

  @override
  String previewStatus(Object status) {
    return '状态：$status';
  }

  @override
  String previewCopyCount(int count) {
    return '复制：$count';
  }

  @override
  String previewDeleteCount(int count) {
    return '删除：$count';
  }

  @override
  String previewConflictCount(int count) {
    return '冲突：$count';
  }

  @override
  String previewCopyBytes(Object size) {
    return '待复制数据量：$size';
  }

  @override
  String get previewBuildPlan => '生成预览';

  @override
  String get previewBuildRemotePlan => '生成远端预览';

  @override
  String get previewPlanItemsTitle => '计划项';

  @override
  String get previewEmptyPlan => '复制、删除和冲突项会显示在这里。';

  @override
  String get previewSectionCopy => '复制项';

  @override
  String get previewSectionDelete => '删除项';

  @override
  String get previewSectionConflict => '冲突项';

  @override
  String get previewNoItemsInSection => '该分组没有条目。';

  @override
  String get previewFilterAll => '全部类型';

  @override
  String get previewFilterTitle => '文件类型';

  @override
  String get previewStalePlan => '已切换目录，请重新生成预览。';

  @override
  String get previewSectionTitle => '分组';

  @override
  String get previewScanTimeout => '扫描可能被超大目录或不可访问目录阻塞。';

  @override
  String previewPartialScanWarning(int count) {
    return '扫描时跳过了 $count 个不可访问的子目录。';
  }

  @override
  String get previewPartialScanAdvice => '预览仍可继续，但结果可能不完整。';

  @override
  String previewSkippedPath(Object path) {
    return '已跳过：$path';
  }

  @override
  String get previewStartSync => '开始同步';

  @override
  String get previewDirectoryRequired => '请先选择本地目录再生成预览。';

  @override
  String get previewRemoteDirectoryRequired => '请先连接远端设备并加载其索引，再生成远端预览。';

  @override
  String get errorRemoteDirectoryNotSelected => '远端设备尚未选择共享目录。';

  @override
  String get errorRemoteDeviceDisconnected => '远端设备已断开连接。请保持目标设备前台运行后重连。';

  @override
  String get errorConnectionRefused => '连接被拒绝。请检查目标地址，并确认远端已开启监听。';

  @override
  String get errorConnectionTimedOut => '连接超时。请确认两台设备处于同一局域网后重试。';

  @override
  String get errorRemoteProtocolInvalid => '远端设备返回了不兼容或无效的协议消息。';

  @override
  String get errorNoRemoteDeviceConnected => '当前没有连接远端设备。';

  @override
  String get errorScanTimedOut => '扫描超时。目录可能过大，或其中包含不可访问的子目录。';

  @override
  String get errorDirectoryUnavailable => '无法访问当前选择的目录，请重新选择可访问的文件夹。';

  @override
  String get errorDirectoryTreeAccessDenied => '扫描失败，目录树中包含不可访问的子目录。';

  @override
  String get errorDirectoryAccessDenied => '目录访问被拒绝，请选择你有权限读取的文件夹。';

  @override
  String get executionConfirmDeleteTitle => '确认删除';

  @override
  String executionConfirmDeleteBody(int count) {
    return '本次同步将删除目标目录中多出的 $count 个条目，是否继续？';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get executionTitle => '执行';

  @override
  String get executionProgressTitle => '进度';

  @override
  String get executionRemotePending => '请先生成远端预览，再执行远端同步。';

  @override
  String get executionRemoteReady => '远端预览已就绪，可按当前预览将本机文件同步到远端。';

  @override
  String get executionKeepForeground => 'Android 作为远端时，请保持目标设备前台运行，不要切到后台或锁屏。';

  @override
  String get executionLocalPending => '本地调试复制仅用于本地预览模式，不属于正式局域网同步流程。';

  @override
  String get executionProgressPlaceholder => '传输进度会显示在这里。';

  @override
  String get executionLogsTitle => '日志';

  @override
  String get executionLogsPlaceholder => '执行日志会显示在这里。';

  @override
  String get executionTargetTitle => '本地调试目标';

  @override
  String get executionTargetHint => '仅用于本地调试链路，不属于正式的局域网同步目标。';

  @override
  String get executionNoTarget => '尚未选择目标目录。';

  @override
  String get executionPickTarget => '选择目标目录';

  @override
  String get executionRun => '执行本地复制';

  @override
  String get executionRunLocalDebug => '执行本地调试复制';

  @override
  String get executionRunRemote => '执行远端同步';

  @override
  String get executionStop => '停止同步';

  @override
  String get executionCancelled => '同步已手动停止。未完成的临时文件已尽量清理。';

  @override
  String executionCurrentFile(Object path) {
    return '当前文件：$path';
  }

  @override
  String executionProgressFiles(int done, int total) {
    return '文件：$done/$total';
  }

  @override
  String get executionTargetRequired => '执行前请先选择本地目标目录。';

  @override
  String get executionPlanSummaryTitle => '执行范围';

  @override
  String executionWillCopy(int count) {
    return '将执行的复制项：$count';
  }

  @override
  String executionWillDelete(int count) {
    return '将执行的删除项：$count';
  }

  @override
  String executionWillSkipConflict(int count) {
    return '冲突项不会执行：$count';
  }

  @override
  String get executionOpenResult => '打开结果';

  @override
  String get resultTitle => '结果';

  @override
  String get resultSummaryTitle => '摘要';

  @override
  String get resultSummaryPlaceholder => '同步结果摘要会显示在这里。';

  @override
  String resultModeLabel(Object mode) {
    return '执行模式：$mode';
  }

  @override
  String get resultModeLocal => '本地调试复制';

  @override
  String get resultModeRemote => '远端同步';

  @override
  String get resultModeUnknown => '未知';

  @override
  String get resultErrorTitle => '错误信息';

  @override
  String get resultAdviceTitle => '建议';

  @override
  String get resultAdviceKeepForeground => '如果远端是 Android，请保持前台运行后重试。';

  @override
  String get resultAdviceRebuildPreview => '如果目录权限或内容已变化，请重新选择目录并重新生成预览。';

  @override
  String resultCopiedCount(int count) {
    return '已复制：$count';
  }

  @override
  String resultDeletedCount(int count) {
    return '已删除：$count';
  }

  @override
  String resultFailedCount(int count) {
    return '失败：$count';
  }

  @override
  String resultTargetRoot(Object path) {
    return '目标目录：$path';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsDefaultsTitle => '默认值';

  @override
  String get settingsDefaultsPlaceholder => '项目级设置会放在这里。';

  @override
  String get statusIdle => '空闲';

  @override
  String get statusListening => '监听中';

  @override
  String get statusConnecting => '连接中';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusDisconnected => '已断开';

  @override
  String get statusFailed => '失败';

  @override
  String get statusLoading => '加载中';

  @override
  String get statusLoaded => '已完成';
}

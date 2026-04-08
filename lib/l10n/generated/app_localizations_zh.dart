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
  String get homeStepConnectionTitle => '步骤 1：连接远端设备';

  @override
  String get homeStepConnectionHint => '建立与远端设备的连接。连接建立后，目录状态与预览会自动更新。';

  @override
  String get homeConnectionStateIdle => '未监听';

  @override
  String get homeConnectionStateConnecting => '连接中';

  @override
  String get homeConnectionStateListening => '监听中';

  @override
  String get homeConnectionStateConnected => '已连接';

  @override
  String homePortChipLabel(int port) {
    return '端口 $port';
  }

  @override
  String get homeShareTooltip => '分享';

  @override
  String get homePortDialogTitle => '设置监听端口';

  @override
  String get homePortDialogBody => '修改后会按新的端口开启监听。';

  @override
  String get homePortDialogHint => '输入端口，例如 44888';

  @override
  String get homePortDialogInvalid => '请输入有效端口（1-65535）。';

  @override
  String get homeShareDialogTitle => '分享地址';

  @override
  String get homeShareCopyDone => '已复制连接地址。';

  @override
  String get homeConnectStop => '停止连接';

  @override
  String get homeStepSourceTitle => '步骤 2：选择本地源目录';

  @override
  String get homeStepSourceHint => '这个目录会被同步到目标端目录。';

  @override
  String get homeClearSelection => '清除';

  @override
  String get homeSourcePendingBecauseRemoteReady => '目标端目录已经准备好，现在只差选择本地源目录。';

  @override
  String get homeStepPreviewTitle => '步骤 3：检查并同步';

  @override
  String get homeStepPreviewHint => '目录就绪后会自动分析；如需重扫目标端，可手动刷新索引。';

  @override
  String get homeAdvancedTitle => '高级与调试';

  @override
  String get homeConnectionHelpersTitle => '连接辅助';

  @override
  String get homeConnectionActionsTitle => '连接操作';

  @override
  String get homeAutoPreviewWaiting => '等待源端目录与目标端目录都准备就绪后自动分析。';

  @override
  String get homeAutoPreviewWaitingLocal => '目标端已就绪，等待选择本地源目录后自动分析。';

  @override
  String get homeAutoPreviewWaitingRemote => '本地源目录已就绪，等待远端设备选择目标端目录后自动分析。';

  @override
  String get homeAutoPreviewRunning => '目录已就绪，正在自动生成目标端预览。';

  @override
  String get homeAutoPreviewReady => '目标端预览已是最新，可直接检查并执行同步。';

  @override
  String get homeAutoPreviewRefresh => '如需强制重扫目标端，可手动刷新目标端索引。';

  @override
  String get homeLocalLibraryTitle => '本地音乐库';

  @override
  String get homeLocalSourceHint => '此目录会作为源端目录，目标端将向它对齐。';

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
  String get homeManageRecentItems => '管理记录';

  @override
  String get homeRecentEmpty => '暂无记录';

  @override
  String get homeRecentAlias => '备注';

  @override
  String get homeRecentDelete => '删除';

  @override
  String get homeRecentEditAlias => '编辑名称';

  @override
  String get homeRecentEditAddress => '编辑地址';

  @override
  String get homeRecentAddressField => '地址';

  @override
  String get homeRecentAddressRequired => '请输入地址';

  @override
  String get homeRecentAliasHint => '输入备注名称';

  @override
  String get homeRemoteTargetTitle => '目标端';

  @override
  String get homeRemoteTargetHint => '当前第一版只支持从本机同步到远端设备的目标端。';

  @override
  String get homeRemoteIndexPending => '目标端目录已就绪，正在同步索引。';

  @override
  String get homeRemoteManualRefreshTitle => '手动刷新';

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
  String get homeRefreshRemoteIndex => '刷新目标端索引';

  @override
  String get homeRefreshRemoteIndexHint => '仅在你怀疑目标端目录变化但自动刷新未跟上时使用。';

  @override
  String homeRemoteRoot(Object name) {
    return '目标端根目录：$name';
  }

  @override
  String homeRemoteIndexedAt(Object value) {
    return '目标端索引时间：$value';
  }

  @override
  String homeRemoteFiles(int count) {
    return '目标端文件数：$count';
  }

  @override
  String get homeOpenPreview => '打开预览';

  @override
  String get previewTitle => '预览';

  @override
  String get previewSummaryTitle => '摘要';

  @override
  String previewTransferDirection(Object source, Object target) {
    return '传输方向：$source -> $target';
  }

  @override
  String get previewDirectionRemote => '目标端';

  @override
  String get previewDirectionLocalTarget => '本地目标端';

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
  String get previewSummaryBytes => '数据量';

  @override
  String get previewSectionAll => '全部项目';

  @override
  String previewTargetIndexedAt(Object value) {
    return '当前目标快照时间：$value';
  }

  @override
  String get previewBuildPlan => '生成预览';

  @override
  String get previewBuildRemotePlan => '生成预览';

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
  String get previewWaitingDirectories => '等待目录就绪';

  @override
  String get previewWaitingLocalDirectory => '等待本地目录';

  @override
  String get previewWaitingRemoteDirectory => '等待目标端目录';

  @override
  String get previewNoSyncItems => '当前没有可同步项目。';

  @override
  String get previewDetailOverviewTitle => '概览';

  @override
  String get previewDetailRelativePath => '相对路径';

  @override
  String get previewDetailSide => '来源范围';

  @override
  String get previewDetailSourceEntry => '源端条目';

  @override
  String get previewDetailTargetEntry => '目标端条目';

  @override
  String get previewDetailName => '名称';

  @override
  String get previewDetailLocation => '位置';

  @override
  String get previewDetailLocationLocal => '本机';

  @override
  String get previewDetailLocationRemote => '目标端';

  @override
  String get previewDetailPath => '路径';

  @override
  String get previewDetailSize => '文件大小';

  @override
  String get previewDetailModifiedTime => '修改时间';

  @override
  String get previewDetailEntryType => '条目类型';

  @override
  String get previewDetailEntryTypeDirectory => '文件夹';

  @override
  String get previewDetailEntryTypeFile => '文件';

  @override
  String get previewDetailAudioTitle => '标题';

  @override
  String get previewDetailAudioArtist => '歌手';

  @override
  String get previewDetailAudioAlbum => '专辑';

  @override
  String get previewDetailAudioLyrics => '歌词';

  @override
  String get previewDetailUnknownValue => '未知';

  @override
  String get previewDetailRefreshing => '正在刷新条目详情...';

  @override
  String get previewDetailRefreshFailed => '刷新条目详情失败，当前显示的是已有数据。';

  @override
  String get previewDetailSideSourceOnly => '仅源端';

  @override
  String get previewDetailSideTargetOnly => '仅目标端';

  @override
  String get previewDetailSideBoth => '源端与目标端';

  @override
  String get previewDetailSideUnknown => '未知';

  @override
  String get previewFilterAll => '全部类型';

  @override
  String previewIgnoredExtensions(Object value) {
    return '已忽略：$value';
  }

  @override
  String get previewFilterMore => '更多';

  @override
  String get previewFilterCollapse => '收起';

  @override
  String get previewFilterTitle => '文件类型';

  @override
  String get previewStalePlan => '已切换目录，请重新生成预览。';

  @override
  String get previewSectionTitle => '分组';

  @override
  String previewSectionCount(int count) {
    return '当前分组条目数：$count';
  }

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
  String get previewRemoteDirectoryRequired => '请先连接远端设备，并让远端设备选择目标端目录。';

  @override
  String get errorRemoteDirectoryNotSelected => '远端设备尚未选择目标端目录。';

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
  String get errorDirectoryNotExists => '当前选择的目录已不存在，请重新选择。';

  @override
  String get errorListenPortInUse => '监听失败：端口已被占用。请更换端口，或关闭占用该端口的程序。';

  @override
  String get errorWindowsWriteCreateFailed =>
      '无法写入 Windows 目标目录。请检查权限和文件占用后重试。';

  @override
  String get errorWindowsRenameFailed => '无法完成一个或多个文件的最终写入。请检查权限和文件占用后重试。';

  @override
  String get errorWindowsDeleteFailed =>
      '无法删除 Windows 目标目录中的一个或多个条目。请检查权限和文件占用后重试。';

  @override
  String get errorWindowsReadFailed => '无法读取一个或多个 Windows 源文件。请检查权限和文件占用后重试。';

  @override
  String get errorWindowsDirectoryCreateFailed =>
      '无法创建一个或多个目标文件夹。请检查权限和路径有效性后重试。';

  @override
  String get errorWindowsDirectoryListingFailed =>
      '无法读取当前 Windows 目录，请重新选择其他文件夹。';

  @override
  String get errorWindowsEntryAccessFailed => '扫描失败，存在一个或多个无法访问的 Windows 条目。';

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
  String get commonAdd => '添加';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get executionTitle => '执行';

  @override
  String get executionProgressTitle => '进度';

  @override
  String executionStateLabel(Object status) {
    return '执行状态：$status';
  }

  @override
  String get executionRemotePending => '请先等待目标端预览完成，再执行同步。';

  @override
  String get executionRemoteReady => '目标端预览已就绪，可按当前预览将本机文件同步到目标端。';

  @override
  String get executionKeepForeground => 'Android 作为目标端时，请保持目标设备前台运行，不要切到后台或锁屏。';

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
  String get executionRunRemote => '开始同步';

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
  String resultStatusLabel(Object status) {
    return '执行状态：$status';
  }

  @override
  String get resultModeLocal => '本地调试复制';

  @override
  String get resultModeRemote => '目标端同步';

  @override
  String get resultModeUnknown => '未知';

  @override
  String get resultStatusCompleted => '已完成';

  @override
  String get resultStatusCancelled => '已取消';

  @override
  String get resultStatusFailed => '失败';

  @override
  String get resultStatusIdle => '空闲';

  @override
  String get resultErrorTitle => '错误信息';

  @override
  String get resultAdviceTitle => '建议';

  @override
  String get resultAdviceKeepForeground => '如果目标端是 Android，请保持前台运行后重试。';

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
  String get settingsGeneralTitle => '常规';

  @override
  String get settingsAppearanceTitle => '外观';

  @override
  String get settingsDefaultsTitle => '默认值';

  @override
  String get settingsDefaultsPlaceholder => '项目级设置会放在这里。';

  @override
  String get settingsRulesTitle => '规则';

  @override
  String get settingsAutoStartListeningTitle => '自动监听';

  @override
  String get settingsAutoStartListeningDescription => '允许 MusicSync 启动时自动开启监听';

  @override
  String get settingsIgnoredExtensionsTitle => '忽略文件类型';

  @override
  String get settingsIgnoredExtensionsDescription => '被忽略的后缀类型会在同步时被跳过';

  @override
  String get settingsIgnoredExtensionsEmpty => '当前没有忽略任何后缀';

  @override
  String settingsIgnoredExtensionsSummary(int count) {
    return '已忽略 $count 个后缀';
  }

  @override
  String get settingsIgnoredExtensionField => '后缀';

  @override
  String get settingsIgnoredExtensionHint => '例如 flac、lrc';

  @override
  String get settingsIgnoredExtensionRequired => '请输入后缀';

  @override
  String get settingsIgnoredExtensionInvalid => '后缀格式无效，只能包含字母、数字、下划线或短横线';

  @override
  String get settingsIgnoredExtensionDuplicate => '这个后缀已经存在';

  @override
  String get settingsThemeModeTitle => '主题模式';

  @override
  String get settingsThemeModeDescription => '选择应用使用浅色、深色或跟随系统。';

  @override
  String get settingsThemeModeLight => '浅色模式';

  @override
  String get settingsThemeModeDark => '深色模式';

  @override
  String get settingsThemeModeSystem => '跟随系统';

  @override
  String get settingsPaletteTitle => '调色板';

  @override
  String get settingsPaletteDescription => '选择一组 Material Design 调色策略。';

  @override
  String get settingsPaletteNeutral => 'Neutral';

  @override
  String get settingsPaletteExpressive => 'Expressive';

  @override
  String get settingsPaletteTonalSpot => 'Tonal Spot';

  @override
  String get previewTransferDirectionLabel => '传输方向';

  @override
  String get previewDirectoryStatusLabel => '目录状态';

  @override
  String get previewDirectoryStatusLocal => '本地';

  @override
  String get previewDirectoryStatusRemote => '目标端';

  @override
  String get diffTypeCopy => '复制';

  @override
  String get diffTypeDelete => '删除';

  @override
  String get diffTypeConflict => '冲突';

  @override
  String get diffTypeSkip => '跳过';

  @override
  String get diffConflictMetadataMismatch => '元数据不同';

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

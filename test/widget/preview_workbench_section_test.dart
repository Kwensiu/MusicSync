import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/generated/app_localizations.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';

void main() {
  testWidgets('shows timeout detail only for scan timeout errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PreviewWorkbenchSection(
          directoryState: const DirectoryState(),
          connectionState: peer_connection.ConnectionState.initial(),
          previewState: PreviewState(
            status: PreviewStatus.failed,
            plan: SyncPlan.empty(),
            errorMessage: 'timeout',
          ),
          executionState: ExecutionState.initial(),
          scanWarnings: const <String>[],
          isStalePlan: false,
          isBusy: false,
          isExecuting: false,
          canStartRemoteSync: false,
          showExecutionPanel: false,
          hasRemoteDirectoryReady: false,
          sourceDeviceLabel: 'Local',
          targetDeviceLabel: 'Remote',
          isTransferConnected: false,
          onBuildRemotePreview: () async {},
          onStartRemoteSync: () async {},
          onCancelSync: () {},
          localizeUiError: (_, value) => value,
          localizedExecutionStatus: (_, _) => '',
          isScanTimeoutError: (String value) => value == 'timeout',
        ),
      ),
    );

    expect(find.text('timeout'), findsOneWidget);
    expect(
      find.text(
        'Scanning may be blocked by a large or inaccessible directory.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _TestApp(
        child: PreviewWorkbenchSection(
          directoryState: const DirectoryState(),
          connectionState: peer_connection.ConnectionState.initial(),
          previewState: PreviewState(
            status: PreviewStatus.failed,
            plan: SyncPlan.empty(),
            errorMessage: 'other-error',
          ),
          executionState: ExecutionState.initial(),
          scanWarnings: const <String>[],
          isStalePlan: false,
          isBusy: false,
          isExecuting: false,
          canStartRemoteSync: false,
          showExecutionPanel: false,
          hasRemoteDirectoryReady: false,
          sourceDeviceLabel: 'Local',
          targetDeviceLabel: 'Remote',
          isTransferConnected: false,
          onBuildRemotePreview: () async {},
          onStartRemoteSync: () async {},
          onCancelSync: () {},
          localizeUiError: (_, value) => value,
          localizedExecutionStatus: (_, _) => '',
          isScanTimeoutError: (String value) => value == 'timeout',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('other-error'), findsOneWidget);
    expect(
      find.text(
        'Scanning may be blocked by a large or inaccessible directory.',
      ),
      findsNothing,
    );
  });

  testWidgets('can hide action buttons while still showing source risk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PreviewWorkbenchSection(
          directoryState: const DirectoryState(),
          connectionState: peer_connection.ConnectionState.initial(),
          previewState: PreviewState(
            status: PreviewStatus.loaded,
            plan: SyncPlan.empty(),
          ),
          executionState: ExecutionState.initial(),
          scanWarnings: const <String>[],
          isStalePlan: false,
          isBusy: false,
          isExecuting: false,
          canStartRemoteSync: false,
          showExecutionPanel: false,
          hasRemoteDirectoryReady: false,
          sourceDeviceLabel: 'Local',
          targetDeviceLabel: 'Remote',
          isTransferConnected: false,
          onBuildRemotePreview: () async {},
          onStartRemoteSync: () async {},
          onCancelSync: () {},
          localizeUiError: (_, value) => value,
          localizedExecutionStatus: (_, _) => '',
          isScanTimeoutError: (_) => false,
          sourceRiskMessage: 'risk',
          showActionButtons: false,
          showBuildPreviewButton: false,
        ),
      ),
    );

    expect(find.text('risk'), findsOneWidget);
    expect(find.text('Build Preview'), findsNothing);
    expect(find.text('Start Sync'), findsNothing);
    expect(find.text('Stop Sync'), findsNothing);
  });

  testWidgets('shows result summary in the execution card after sync ends', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PreviewWorkbenchSection(
          directoryState: const DirectoryState(),
          connectionState: peer_connection.ConnectionState.initial(),
          previewState: PreviewState(
            status: PreviewStatus.loaded,
            plan: SyncPlan.empty(),
          ),
          executionState: ExecutionState(
            status: ExecutionStatus.completed,
            progress: ExecutionState.initial().progress,
            result: const ExecutionResult(
              copiedCount: 12,
              deletedCount: 3,
              failedCount: 1,
              totalBytes: 2048,
              targetRoot: 'remote-root',
            ),
            targetRoot: 'remote-root',
          ),
          scanWarnings: const <String>[],
          isStalePlan: false,
          isBusy: false,
          isExecuting: false,
          canStartRemoteSync: false,
          showExecutionPanel: true,
          hasRemoteDirectoryReady: false,
          sourceDeviceLabel: 'Local',
          targetDeviceLabel: 'Remote',
          isTransferConnected: false,
          onBuildRemotePreview: () async {},
          onStartRemoteSync: () async {},
          onCancelSync: () {},
          localizeUiError: (_, value) => value,
          localizedExecutionStatus: (_, _) => 'completed',
          isScanTimeoutError: (_) => false,
        ),
      ),
    );

    expect(find.text('Processed: 0 / 0'), findsOneWidget);
    expect(find.text('Copy 12'), findsOneWidget);
    expect(find.text('Delete 3'), findsOneWidget);
    expect(find.text('Failed 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'does not show success banner when completed result has failures',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: PreviewWorkbenchSection(
            directoryState: const DirectoryState(),
            connectionState: peer_connection.ConnectionState.initial(),
            previewState: PreviewState(
              status: PreviewStatus.loaded,
              plan: SyncPlan.empty(),
            ),
            executionState: const ExecutionState(
              status: ExecutionStatus.completed,
              progress: TransferProgress(
                stage: SyncStage.completed,
                processedFiles: 2,
                totalFiles: 3,
                processedBytes: 1024,
                totalBytes: 2048,
                copiedCount: 1,
                deletedCount: 0,
                failedCount: 1,
              ),
              result: ExecutionResult(
                copiedCount: 1,
                deletedCount: 0,
                failedCount: 1,
                totalBytes: 1024,
                targetRoot: 'remote-root',
              ),
              targetRoot: 'remote-root',
              errorMessage: 'partial-failure',
            ),
            scanWarnings: const <String>[],
            isStalePlan: false,
            isBusy: false,
            isExecuting: false,
            canStartRemoteSync: false,
            showExecutionPanel: true,
            hasRemoteDirectoryReady: false,
            sourceDeviceLabel: 'Local',
            targetDeviceLabel: 'Remote',
            isTransferConnected: false,
            onBuildRemotePreview: () async {},
            onStartRemoteSync: () async {},
            onCancelSync: () {},
            localizeUiError: (_, value) => value,
            localizedExecutionStatus: (_, _) => 'completed',
            isScanTimeoutError: (_) => false,
          ),
        ),
      );

      expect(find.text('Completed'), findsNothing);
      expect(find.text('partial-failure'), findsOneWidget);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

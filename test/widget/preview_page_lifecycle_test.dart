import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/presentation/pages/preview_page.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/generated/app_localizations.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:smooth_list_view/smooth_list_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PreviewPage presents detail-layer summary and plan sections', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        connectionControllerProvider.overrideWith(
          _PreviewLifecycleConnectionController.new,
        ),
        directoryControllerProvider.overrideWith(
          _PreviewLifecycleDirectoryController.new,
        ),
        previewControllerProvider.overrideWith(
          _PreviewLifecyclePreviewController.new,
        ),
        executionControllerProvider.overrideWith(
          _PreviewLifecycleExecutionController.new,
        ),
        settingsControllerProvider.overrideWith(
          _PreviewLifecycleSettingsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreviewPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Plan Items'), findsOneWidget);
    expect(find.text('No items to sync right now.'), findsOneWidget);
  });

  testWidgets('PreviewPage refreshes remote snapshot when app resumes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        connectionControllerProvider.overrideWith(
          _PreviewLifecycleConnectionController.new,
        ),
        directoryControllerProvider.overrideWith(
          _PreviewLifecycleDirectoryController.new,
        ),
        previewControllerProvider.overrideWith(
          _PreviewLifecyclePreviewController.new,
        ),
        executionControllerProvider.overrideWith(
          _PreviewLifecycleExecutionController.new,
        ),
        settingsControllerProvider.overrideWith(
          _PreviewLifecycleSettingsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreviewPage(),
        ),
      ),
    );
    await tester.pump();

    final _PreviewLifecycleConnectionController controller =
        container.read(connectionControllerProvider.notifier)
            as _PreviewLifecycleConnectionController;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.refreshRemoteSnapshotCallCount, 1);
    expect(controller.lastClearTransientState, isFalse);
  });

  testWidgets(
    'PreviewPage binds Scrollbar and scrollable without ScrollPosition errors',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          connectionControllerProvider.overrideWith(
            _PreviewLifecycleConnectionController.new,
          ),
          directoryControllerProvider.overrideWith(
            _PreviewLifecycleDirectoryController.new,
          ),
          previewControllerProvider.overrideWith(
            _PreviewLifecyclePreviewController.new,
          ),
          executionControllerProvider.overrideWith(
            _PreviewLifecycleExecutionController.new,
          ),
          settingsControllerProvider.overrideWith(
            _PreviewLifecycleSettingsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PreviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.byType(SmoothListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PreviewPage desktop layout moves summary and actions to sidebar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          connectionControllerProvider.overrideWith(
            _PreviewLifecycleConnectionController.new,
          ),
          directoryControllerProvider.overrideWith(
            _PreviewLifecycleDirectoryController.new,
          ),
          previewControllerProvider.overrideWith(
            _PreviewLifecyclePreviewController.new,
          ),
          executionControllerProvider.overrideWith(
            _PreviewLifecycleExecutionController.new,
          ),
          settingsControllerProvider.overrideWith(
            _PreviewLifecycleSettingsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PreviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsNothing);
      expect(find.text('Transfer Status'), findsNothing);
      expect(find.text('Directory Status'), findsNothing);
      expect(find.text('Filters & Summary'), findsOneWidget);
      expect(find.text('Build Preview'), findsOneWidget);
      expect(find.text('Start Sync'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PreviewLifecycleConnectionController extends ConnectionController {
  int refreshRemoteSnapshotCallCount = 0;
  bool? lastClearTransientState;

  @override
  peer_connection.ConnectionState build() {
    return peer_connection.ConnectionState(
      status: peer_connection.ConnectionStatus.connected,
      peer: const DeviceInfo(
        deviceId: 'peer-device',
        deviceName: 'Peer',
        platform: 'android',
        address: '192.168.1.8',
        port: 44888,
      ),
      remoteSnapshot: _remoteSnapshot(),
      isRemoteDirectoryReady: true,
    );
  }

  @override
  Future<ScanSnapshot?> refreshRemoteSnapshot({
    bool clearTransientState = true,
  }) async {
    refreshRemoteSnapshotCallCount++;
    lastClearTransientState = clearTransientState;
    return state.remoteSnapshot;
  }
}

class _PreviewLifecycleDirectoryController extends DirectoryController {
  @override
  DirectoryState build() {
    return const DirectoryState(
      handle: DirectoryHandle(entryId: 'local-root', displayName: 'Music'),
    );
  }
}

class _PreviewLifecyclePreviewController extends PreviewController {
  @override
  PreviewState build() {
    return PreviewState(
      status: PreviewStatus.loaded,
      mode: PreviewMode.remote,
      plan: SyncPlan.empty(),
      sourceRootId: 'local-root',
      sourceSnapshot: _localSnapshot(),
      targetSnapshot: _remoteSnapshot(),
    );
  }
}

class _PreviewLifecycleExecutionController extends ExecutionController {
  @override
  ExecutionState build() => ExecutionState.initial();
}

class _PreviewLifecycleSettingsController extends SettingsController {
  @override
  SettingsState build() {
    return const SettingsState(
      deviceAlias: 'Studio PC',
      deviceDisplayName: 'Studio PC',
    );
  }
}

ScanSnapshot _remoteSnapshot() {
  return ScanSnapshot(
    rootId: 'remote-root',
    rootDisplayName: 'Remote',
    deviceId: 'peer-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: const [],
    cacheVersion: 1,
  );
}

ScanSnapshot _localSnapshot() {
  return ScanSnapshot(
    rootId: 'local-root',
    rootDisplayName: 'Music',
    deviceId: 'local-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: const [],
    cacheVersion: 1,
  );
}

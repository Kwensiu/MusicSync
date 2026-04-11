import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_page_content.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peer_connection.ConnectionState connectionState = ref.watch(
      connectionControllerProvider,
    );
    final directoryState = ref.watch(directoryControllerProvider);
    final PreviewState previewState = ref.watch(previewControllerProvider);
    final int previewItemCount =
        previewState.plan.copyItems.length +
        previewState.plan.deleteItems.length +
        previewState.plan.conflictItems.length;
    final bool hasSourceDirectory = directoryState.handle != null;
    final bool hasConnectedPeer =
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;

    return AppScaffold(
      title: context.l10n.homeOverviewTitle,
      showBackButton: false,
      actions: <Widget>[
        IconButton(
          onPressed: () => context.pushNamed(RouteNames.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: AppPageContent(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 900;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _HeroCard(
                  headline: context.l10n.homeOverviewHeadline,
                  body: context.l10n.homeOverviewBody,
                  primaryLabel: context.l10n.homeOpenTransferPage,
                  onPrimaryPressed: () =>
                      context.pushNamed(RouteNames.transfer),
                ),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _buildStatusCard(
                          context,
                          connectionLabel: _connectionSummary(
                            context,
                            connectionState,
                          ),
                          sourceLabel: hasSourceDirectory
                              ? context.l10n.homeSourceStateReady
                              : context.l10n.homeSourceStatePending,
                          previewLabel:
                              previewState.status == PreviewStatus.loaded
                              ? context.l10n.homeOverviewPreviewReady(
                                  previewItemCount,
                                )
                              : context.l10n.homeOverviewPreviewPending,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNextStepCard(
                          context,
                          hasConnectedPeer: hasConnectedPeer,
                          hasSourceDirectory: hasSourceDirectory,
                          previewState: previewState,
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  _buildStatusCard(
                    context,
                    connectionLabel: _connectionSummary(
                      context,
                      connectionState,
                    ),
                    sourceLabel: hasSourceDirectory
                        ? context.l10n.homeSourceStateReady
                        : context.l10n.homeSourceStatePending,
                    previewLabel: previewState.status == PreviewStatus.loaded
                        ? context.l10n.homeOverviewPreviewReady(
                            previewItemCount,
                          )
                        : context.l10n.homeOverviewPreviewPending,
                  ),
                  const SizedBox(height: 16),
                  _buildNextStepCard(
                    context,
                    hasConnectedPeer: hasConnectedPeer,
                    hasSourceDirectory: hasSourceDirectory,
                    previewState: previewState,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String connectionLabel,
    required String sourceLabel,
    required String previewLabel,
  }) {
    return SectionCard(
      title: context.l10n.homeOverviewStatusTitle,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          _OverviewPill(
            title: context.l10n.homeOverviewConnectionLabel,
            value: connectionLabel,
            icon: Icons.devices_outlined,
          ),
          _OverviewPill(
            title: context.l10n.homeOverviewSourceLabel,
            value: sourceLabel,
            icon: Icons.folder_outlined,
          ),
          _OverviewPill(
            title: context.l10n.homeOverviewPreviewLabel,
            value: previewLabel,
            icon: Icons.library_music_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard(
    BuildContext context, {
    required bool hasConnectedPeer,
    required bool hasSourceDirectory,
    required PreviewState previewState,
  }) {
    final String message = switch ((hasConnectedPeer, hasSourceDirectory)) {
      (false, _) => context.l10n.homeOverviewNextConnect,
      (true, false) => context.l10n.homeOverviewNextPickSource,
      (true, true) when previewState.status != PreviewStatus.loaded =>
        context.l10n.homeOverviewNextBuildPreview,
      _ => context.l10n.homeOverviewNextOpenTransfer,
    };

    return SectionCard(
      title: context.l10n.homeOverviewNextTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.pushNamed(RouteNames.transfer),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: Text(context.l10n.homeOpenTransferPage),
          ),
        ],
      ),
    );
  }

  String _connectionSummary(
    BuildContext context,
    peer_connection.ConnectionState connectionState,
  ) {
    if (connectionState.status == peer_connection.ConnectionStatus.idle &&
        connectionState.isListening) {
      return context.l10n.homeConnectionStateListening;
    }
    return switch (connectionState.status) {
      peer_connection.ConnectionStatus.connected =>
        context.l10n.homeConnectionStateConnected,
      peer_connection.ConnectionStatus.connecting =>
        context.l10n.homeConnectionStateConnecting,
      peer_connection.ConnectionStatus.disconnected =>
        context.l10n.homeConnectionStateDisconnected,
      peer_connection.ConnectionStatus.failed =>
        context.l10n.homeConnectionStateDisconnected,
      peer_connection.ConnectionStatus.idle =>
        context.l10n.homeConnectionStateIdle,
    };
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.headline,
    required this.body,
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final String headline;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.multitrack_audio_rounded,
              size: 36,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPrimaryPressed,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimaryContainer,
                foregroundColor: scheme.primaryContainer,
              ),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

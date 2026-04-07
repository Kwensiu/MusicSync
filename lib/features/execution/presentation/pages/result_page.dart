import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/l10n/app_localizations_x.dart';

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final executionState = ref.watch(executionControllerProvider);

    return AppScaffold(
      title: context.l10n.resultTitle,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SectionCard(
          title: context.l10n.resultSummaryTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.resultModeLabel(
                  _localizedExecutionMode(context, executionState.mode),
                ),
              ),
              Text(context.l10n.resultCopiedCount(executionState.result.copiedCount)),
              Text(context.l10n.resultDeletedCount(executionState.result.deletedCount)),
              Text(context.l10n.resultFailedCount(executionState.result.failedCount)),
              if (executionState.result.targetRoot.isNotEmpty)
                Text(context.l10n.resultTargetRoot(executionState.result.targetRoot)),
              if (executionState.result.totalBytes > 0)
                Text(formatBytes(executionState.result.totalBytes)),
              if (executionState.errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  context.l10n.resultErrorTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(executionState.errorMessage!),
                const SizedBox(height: 8),
                Text(
                  context.l10n.resultAdviceTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                if (executionState.mode == ExecutionMode.remote)
                  Text(context.l10n.resultAdviceKeepForeground),
                Text(context.l10n.resultAdviceRebuildPreview),
              ],
              if (executionState.result.copiedCount == 0 &&
                  executionState.result.deletedCount == 0 &&
                  executionState.result.failedCount == 0)
                Text(context.l10n.resultSummaryPlaceholder),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedExecutionMode(BuildContext context, ExecutionMode mode) {
    switch (mode) {
      case ExecutionMode.local:
        return context.l10n.resultModeLocal;
      case ExecutionMode.remote:
        return context.l10n.resultModeRemote;
      case ExecutionMode.none:
        return context.l10n.resultModeUnknown;
    }
  }
}

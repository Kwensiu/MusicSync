import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/features/preview/presentation/widgets/conflict/preview_conflict_detail_pane.dart';
import 'package:music_sync/features/preview/presentation/widgets/conflict/preview_conflict_list_pane.dart';
import 'package:music_sync/features/preview/state/conflict_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewConflictPage extends ConsumerStatefulWidget {
  const PreviewConflictPage({super.key});

  @override
  ConsumerState<PreviewConflictPage> createState() =>
      _PreviewConflictPageState();
}

class _PreviewConflictPageState extends ConsumerState<PreviewConflictPage> {
  @override
  Widget build(BuildContext context) {
    final ConflictState conflictState = ref.watch(conflictControllerProvider);
    final int totalCount = conflictState.items.length;

    return AppScaffold(
      title: context.l10n.conflictPageTitle(totalCount),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = constraints.maxWidth >= 700;

          if (isDesktop) {
            return _DesktopLayout(conflictState: conflictState);
          }

          return _MobileLayout(conflictState: conflictState);
        },
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.conflictState});

  final ConflictState conflictState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: PreviewConflictListPane(
              items: conflictState.items,
              categories: conflictState.categories,
              drafts: conflictState.drafts,
              selectedItemPath: conflictState.selectedItemPath,
              onSelectItem: (String path) {
                ref.read(conflictControllerProvider.notifier).selectItem(path);
              },
            ),
          ),
        ),
        SizedBox(
          width: (MediaQuery.sizeOf(context).width * 0.38).clamp(320.0, 480.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: PreviewConflictDetailPane(
              selectedItem: conflictState.selectedItem,
              draft: conflictState.selectedItem != null
                  ? conflictState.drafts[conflictState
                        .selectedItem!
                        .relativePath]
                  : null,
              category: conflictState.selectedItem != null
                  ? conflictState.categories[conflictState
                        .selectedItem!
                        .relativePath]
                  : null,
              sourceIsRemote: false,
              targetIsRemote: true,
              sideBySide: true,
              onResolve: (String path, ConflictResolutionAction action) {
                ref
                    .read(conflictControllerProvider.notifier)
                    .setDraft(path, action);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.conflictState});

  final ConflictState conflictState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PreviewConflictListPane(
        shrinkWrap: true,
        items: conflictState.items,
        categories: conflictState.categories,
        drafts: conflictState.drafts,
        selectedItemPath: conflictState.selectedItemPath,
        onSelectItem: (String path) {
          ref.read(conflictControllerProvider.notifier).selectItem(path);
          _showDetailSheet(context, ref, conflictState);
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    ConflictState state,
  ) {
    final DiffItem? item = state.selectedItem;
    if (item == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                PreviewConflictDetailPane(
                  shrinkWrap: true,
                  selectedItem: item,
                  draft: state.drafts[item.relativePath],
                  category: state.categories[item.relativePath],
                  sourceIsRemote: false,
                  targetIsRemote: true,
                  onResolve: (String path, ConflictResolutionAction action) {
                    ref
                        .read(conflictControllerProvider.notifier)
                        .setDraft(path, action);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

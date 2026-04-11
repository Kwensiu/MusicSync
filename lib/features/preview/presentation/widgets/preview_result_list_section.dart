import 'package:flutter/material.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_plan_section.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewResultListSection extends StatelessWidget {
  const PreviewResultListSection({
    super.key,
    required this.filteredCopyItems,
    required this.filteredDeleteItems,
    required this.filteredConflictItems,
    required this.activeItems,
    required this.extensionOptions,
    required this.ignoredExtensions,
    required this.isAllExtensionsSelected,
    required this.selectAllSections,
    required this.selectedSections,
    required this.selectedExtensions,
    required this.isBusy,
    required this.previewMode,
    required this.onToggleSection,
    required this.onToggleExtension,
  });

  final List<DiffItem> filteredCopyItems;
  final List<DiffItem> filteredDeleteItems;
  final List<DiffItem> filteredConflictItems;
  final List<DiffItem> activeItems;
  final List<String> extensionOptions;
  final List<String> ignoredExtensions;
  final bool isAllExtensionsSelected;
  final bool selectAllSections;
  final Set<DiffType> selectedSections;
  final Set<String> selectedExtensions;
  final bool isBusy;
  final PreviewMode previewMode;
  final ValueChanged<DiffType?> onToggleSection;
  final ValueChanged<String> onToggleExtension;

  @override
  Widget build(BuildContext context) {
    return PreviewPlanSection(
      header: _FilterPanel(
        sectionTitle: context.l10n.previewSectionTitle,
        sectionChild: Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              <_SectionOption>[
                _SectionOption(
                  type: null,
                  label:
                      '${context.l10n.previewSectionAll} ${filteredCopyItems.length + filteredDeleteItems.length}',
                ),
                _SectionOption(
                  type: DiffType.copy,
                  label:
                      '${context.l10n.previewSectionCopy} ${filteredCopyItems.length}',
                ),
                _SectionOption(
                  type: DiffType.delete,
                  label:
                      '${context.l10n.previewSectionDelete} ${filteredDeleteItems.length}',
                ),
              ].map((option) {
                final bool selected = option.type == null
                    ? selectAllSections
                    : (!selectAllSections &&
                          selectedSections.contains(option.type));
                return _CompactFilterChip(
                  label: option.label,
                  selected: selected,
                  onSelected: (_) => onToggleSection(option.type),
                );
              }).toList(),
        ),
        filterTitle: extensionOptions.length > 1
            ? context.l10n.previewFilterTitle
            : null,
        filterSummary:
            extensionOptions.length > 1 && ignoredExtensions.isNotEmpty
            ? context.l10n.previewIgnoredExtensions(
                ignoredExtensions.map((String value) => '.$value').join(', '),
              )
            : null,
        filterChild: extensionOptions.length > 1
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extensionOptions.map((String extension) {
                  final bool selected = extension == '*'
                      ? isAllExtensionsSelected
                      : selectedExtensions.contains(extension);
                  return _CompactFilterChip(
                    label: extension == '*'
                        ? context.l10n.previewFilterAll
                        : extension,
                    selected: selected,
                    onSelected: isBusy
                        ? null
                        : (_) => onToggleExtension(extension),
                  );
                }).toList(),
              )
            : null,
      ),
      items: activeItems,
      conflictItems: filteredConflictItems,
      targetIsRemote: previewMode == PreviewMode.remote,
    );
  }
}

class _SectionOption {
  const _SectionOption({required this.type, required this.label});

  final DiffType? type;
  final String label;
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.sectionTitle,
    required this.sectionChild,
    this.filterTitle,
    this.filterSummary,
    this.filterChild,
  });

  final String sectionTitle;
  final Widget sectionChild;
  final String? filterTitle;
  final String? filterSummary;
  final Widget? filterChild;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FilterHeader(title: sectionTitle),
          const SizedBox(height: 8),
          sectionChild,
          if (filterChild != null && filterTitle != null) ...<Widget>[
            const SizedBox(height: 10),
            _FilterHeader(
              title: filterTitle!,
              trailing: filterSummary == null
                  ? null
                  : Text(
                      filterSummary!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            filterChild!,
          ],
        ],
      ),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          Expanded(child: trailing!),
        ],
      ],
    );
  }
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

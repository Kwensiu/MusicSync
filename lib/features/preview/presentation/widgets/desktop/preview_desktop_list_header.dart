import 'package:flutter/material.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewDesktopListHeader extends StatefulWidget {
  const PreviewDesktopListHeader({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectAllSections,
    required this.selectedSections,
    required this.onToggleSection,
    required this.activeItemCount,
    required this.filteredCopyCount,
    required this.filteredDeleteCount,
    required this.filteredConflictCount,
    super.key,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool selectAllSections;
  final Set<DiffType> selectedSections;
  final ValueChanged<DiffType?> onToggleSection;
  final int activeItemCount;
  final int filteredCopyCount;
  final int filteredDeleteCount;
  final int filteredConflictCount;

  @override
  State<PreviewDesktopListHeader> createState() =>
      _PreviewDesktopListHeaderState();
}

class _PreviewDesktopListHeaderState extends State<PreviewDesktopListHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant PreviewDesktopListHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _controller.text != widget.searchQuery) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          onChanged: widget.onSearchChanged,
          controller: _controller,
          decoration: InputDecoration(
            hintText: context.l10n.previewSearchHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              <_SectionOption>[
                _SectionOption(
                  type: null,
                  label:
                      '${context.l10n.previewSectionAll} ${widget.activeItemCount}',
                ),
                _SectionOption(
                  type: DiffType.copy,
                  label:
                      '${context.l10n.previewSectionCopy} ${widget.filteredCopyCount}',
                ),
                _SectionOption(
                  type: DiffType.delete,
                  label:
                      '${context.l10n.previewSectionDelete} ${widget.filteredDeleteCount}',
                ),
                _SectionOption(
                  type: DiffType.conflict,
                  label:
                      '${context.l10n.previewSectionConflict} ${widget.filteredConflictCount}',
                ),
              ].map((option) {
                final bool selected = option.type == null
                    ? widget.selectAllSections
                    : (!widget.selectAllSections &&
                          widget.selectedSections.contains(option.type));
                return FilterChip(
                  label: Text(option.label),
                  selected: selected,
                  onSelected: (_) => widget.onToggleSection(option.type),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  side: BorderSide(color: scheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _SectionOption {
  const _SectionOption({required this.type, required this.label});

  final DiffType? type;
  final String label;
}

import 'package:flutter/material.dart';
import 'package:music_sync/core/utils/extension_normalizer.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_dialog_shell.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

Future<void> showIgnoredFileTypesDialog({
  required BuildContext context,
  required List<String> initialValues,
  required Future<void> Function(List<String> values) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return _IgnoredFileTypesDialog(
        initialValues: initialValues,
        onSave: onSave,
      );
    },
  );
}

class _IgnoredFileTypesDialog extends StatefulWidget {
  const _IgnoredFileTypesDialog({
    required this.initialValues,
    required this.onSave,
  });

  final List<String> initialValues;
  final Future<void> Function(List<String> values) onSave;

  @override
  State<_IgnoredFileTypesDialog> createState() =>
      _IgnoredFileTypesDialogState();
}

class _IgnoredFileTypesDialogState extends State<_IgnoredFileTypesDialog> {
  static const double _gapS = 8;
  static const double _gapM = 10;
  static const double _gapL = 12;
  static const double _fieldRadius = 14;
  static const double _itemRadius = 16;

  final TextEditingController _controller = TextEditingController();
  final RegExp _extensionPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,15}$');

  late List<String> _values = List<String>.from(widget.initialValues);
  String? _inputError;
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SettingsDialogShell(
      title: Text(context.l10n.settingsIgnoredExtensionsTitle),
      maxWidth: 500,
      maxHeight: 430,
      minHorizontalInset: 18,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.settingsIgnoredExtensionsDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: _gapL),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: context.l10n.settingsIgnoredExtensionField,
                    hintText: context.l10n.settingsIgnoredExtensionHint,
                    errorText: _inputError,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_fieldRadius),
                    ),
                  ),
                  onSubmitted: (_) => _addValue(),
                ),
              ),
              const SizedBox(width: _gapS),
              FilledButton(
                onPressed: _isSaving ? null : _addValue,
                child: Text(context.l10n.commonAdd),
              ),
            ],
          ),
          const SizedBox(height: _gapL),
          Expanded(
            child: _values.isEmpty
                ? Center(
                    child: Text(context.l10n.settingsIgnoredExtensionsEmpty),
                  )
                : ListView.separated(
                    itemCount: _values.length,
                    separatorBuilder: (_, _) => const SizedBox(height: _gapS),
                    itemBuilder: (BuildContext context, int index) {
                      final String value = _values[index];
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(_itemRadius),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text('.$value'),
                          trailing: IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _values.removeAt(index);
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(context.l10n.commonConfirm),
        ),
      ],
      bottomActionPadding: _gapM,
      topContentPadding: _gapS,
    );
  }

  void _addValue() {
    final String normalized = normalizeExtensionRule(_controller.text);
    if (normalized.isEmpty) {
      setState(() {
        _inputError = context.l10n.settingsIgnoredExtensionRequired;
      });
      return;
    }
    if (!_extensionPattern.hasMatch(normalized)) {
      setState(() {
        _inputError = context.l10n.settingsIgnoredExtensionInvalid;
      });
      return;
    }
    if (_values.contains(normalized)) {
      setState(() {
        _inputError = context.l10n.settingsIgnoredExtensionDuplicate;
      });
      return;
    }
    setState(() {
      _values = <String>[..._values, normalized]..sort();
      _inputError = null;
      _controller.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    await widget.onSave(List<String>.from(_values));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

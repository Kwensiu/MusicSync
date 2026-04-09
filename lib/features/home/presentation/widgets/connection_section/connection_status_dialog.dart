import 'package:flutter/material.dart';
import 'package:music_sync/app/widgets/app_dialog_shell.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class ConnectionStatusDialog extends StatefulWidget {
  const ConnectionStatusDialog({
    required this.listenPort,
    required this.isListening,
    required this.onSavePort,
    required this.onToggleListening,
    super.key,
  });

  final int listenPort;
  final bool isListening;
  final Future<void> Function(int port) onSavePort;
  final Future<void> Function() onToggleListening;

  @override
  State<ConnectionStatusDialog> createState() => _ConnectionStatusDialogState();
}

class _ConnectionStatusDialogState extends State<ConnectionStatusDialog> {
  static const double _contentTopPadding = 8;
  static const double _contentBottomPadding = 8;
  static const double _titleTopPadding = 16;
  static const double _titleHorizontalPadding = 20;
  static const double _sectionGap = 8;
  static const double _labelToValueGap = 4;
  static const double _portRowMinHeight = 32;
  static const double _portActionSlotWidth = 30;
  static const double _portActionSlotSize = 30;
  static const double _statusCardRadius = 16;
  static const double _statusCardHorizontalPadding = 16;
  static const double _statusCardVerticalPadding = 12;
  static const double _actionButtonRadius = 12;
  static const double _inputActionIconSize = 20;

  late final TextEditingController _portController = TextEditingController(
    text: widget.listenPort.toString(),
  );
  bool _isEditingPort = false;
  bool _isSubmitting = false;
  String? _portError;

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _savePort() async {
    final int? port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _portError = context.l10n.homePortDialogInvalid;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _portError = null;
    });
    await widget.onSavePort(port);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _toggleListening() async {
    setState(() => _isSubmitting = true);
    await widget.onToggleListening();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ButtonStyle baseActionButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_actionButtonRadius),
      ),
    );
    final ButtonStyle stopActionButtonStyle = baseActionButtonStyle.copyWith(
      backgroundColor: WidgetStatePropertyAll<Color>(
        scheme.surfaceContainerHighest,
      ),
      foregroundColor: WidgetStatePropertyAll<Color>(scheme.onSurfaceVariant),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
    );

    return AppDialogShell(
      size: AppDialogSize.compact,
      maxHeight: 260,
      titlePadding: const EdgeInsets.fromLTRB(
        _titleHorizontalPadding,
        _titleTopPadding,
        _titleHorizontalPadding,
        0,
      ),
      topContentPadding: _contentTopPadding,
      bottomContentPadding: _contentBottomPadding,
      title: Text(context.l10n.homePortConfigTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: _isSubmitting
                ? null
                : () => setState(() {
                      _isEditingPort = true;
                    }),
            borderRadius: BorderRadius.circular(_statusCardRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(_statusCardRadius),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _statusCardHorizontalPadding,
                  vertical: _statusCardVerticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.homeListenerTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: _labelToValueGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: _portRowMinHeight,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: !_isEditingPort
                                  ? Text(
                                      '${widget.listenPort}',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : Transform.translate(
                                      offset: const Offset(0, 0),
                                      child: TextField(
                                        controller: _portController,
                                        enabled: !_isSubmitting,
                                        autofocus: true,
                                        keyboardType: TextInputType.number,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText:
                                              context.l10n.homePortDialogHint,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          errorText: _portError,
                                        ),
                                        onSubmitted: (_) => _savePort(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: _portActionSlotWidth,
                          child: Center(
                            child: _isEditingPort
                                ? SizedBox(
                                    width: _portActionSlotSize,
                                    height: _portActionSlotSize,
                                    child: FilledButton(
                                      onPressed:
                                          _isSubmitting ? null : _savePort,
                                      style: FilledButton.styleFrom(
                                        shape: const CircleBorder(),
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(
                                          _portActionSlotSize,
                                          _portActionSlotSize,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: _inputActionIconSize,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: _portActionSlotSize,
                                    height: _portActionSlotSize,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _sectionGap),
          if (widget.isListening)
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _toggleListening,
              style: stopActionButtonStyle,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: Text(context.l10n.homeListenerStop),
            )
          else
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _toggleListening,
              style: baseActionButtonStyle,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: Text(context.l10n.homeListenerStart),
            ),
        ],
      ),
      actions: const <Widget>[],
    );
  }
}

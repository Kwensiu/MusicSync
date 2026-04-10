import 'package:flutter/material.dart';

enum AppDialogSize { micro, compact, form, panel }

class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    required this.title,
    required this.content,
    this.size = AppDialogSize.panel,
    this.actions = const <Widget>[],
    this.onClose,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.minHorizontalInset,
    this.minVerticalInset,
    this.titlePadding,
    this.radius = 24,
    this.horizontalPadding = 20,
    this.topContentPadding = 8,
    this.bottomContentPadding = 0,
    this.bottomActionPadding = 12,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final AppDialogSize size;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;
  final double? minHorizontalInset;
  final double? minVerticalInset;
  final EdgeInsetsGeometry? titlePadding;
  final double radius;
  final double horizontalPadding;
  final double topContentPadding;
  final double bottomContentPadding;
  final double bottomActionPadding;

  @override
  Widget build(BuildContext context) {
    final double resolvedMaxWidth = maxWidth ?? _defaultMaxWidth(size);
    final double resolvedMinWidth = minWidth ?? _defaultMinWidth(size);
    final double resolvedMaxHeight = maxHeight ?? _defaultMaxHeight(size);
    final double resolvedHorizontalInset =
        minHorizontalInset ?? _defaultHorizontalInset(size);
    final double resolvedVerticalInset =
        minVerticalInset ?? _defaultVerticalInset(size);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double targetWidth = (screenWidth - (resolvedHorizontalInset * 2))
        .clamp(resolvedMinWidth, resolvedMaxWidth);
    final ThemeData baseTheme = Theme.of(context);
    final bool hasActions = actions.isNotEmpty;
    final ButtonStyle actionButtonStyle = const ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(88, 40)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      visualDensity: VisualDensity(horizontal: -1, vertical: -1),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Theme(
      data: baseTheme.copyWith(
        textButtonTheme: TextButtonThemeData(style: actionButtonStyle),
        filledButtonTheme: FilledButtonThemeData(style: actionButtonStyle),
      ),
      child: AlertDialog(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        insetPadding: EdgeInsets.symmetric(
          horizontal: resolvedHorizontalInset,
          vertical: resolvedVerticalInset,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        titlePadding: titlePadding,
        title: Row(
          children: <Widget>[
            Expanded(child: title),
            if (onClose != null) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
        contentPadding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topContentPadding,
          horizontalPadding,
          hasActions ? bottomContentPadding : bottomActionPadding,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: targetWidth,
            maxWidth: targetWidth,
            maxHeight: resolvedMaxHeight,
          ),
          child: content,
        ),
        actionsPadding: hasActions
            ? EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                bottomActionPadding,
              )
            : EdgeInsets.zero,
        actions: hasActions ? actions : null,
      ),
    );
  }

  double _defaultMaxWidth(AppDialogSize size) {
    return switch (size) {
      AppDialogSize.micro => 228,
      AppDialogSize.compact => 360,
      AppDialogSize.form => 420,
      AppDialogSize.panel => 640,
    };
  }

  double _defaultMinWidth(AppDialogSize size) {
    return switch (size) {
      AppDialogSize.micro => 228,
      AppDialogSize.compact => 280,
      AppDialogSize.form => 280,
      AppDialogSize.panel => 280,
    };
  }

  double _defaultMaxHeight(AppDialogSize size) {
    return switch (size) {
      AppDialogSize.micro => 320,
      AppDialogSize.compact => 280,
      AppDialogSize.form => 360,
      AppDialogSize.panel => 560,
    };
  }

  double _defaultHorizontalInset(AppDialogSize size) {
    return switch (size) {
      AppDialogSize.micro => 24,
      AppDialogSize.compact => 24,
      AppDialogSize.form => 20,
      AppDialogSize.panel => 20,
    };
  }

  double _defaultVerticalInset(AppDialogSize size) {
    return switch (size) {
      AppDialogSize.micro => 24,
      AppDialogSize.compact => 24,
      AppDialogSize.form => 24,
      AppDialogSize.panel => 24,
    };
  }
}

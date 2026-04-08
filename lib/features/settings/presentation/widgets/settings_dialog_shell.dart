import 'package:flutter/material.dart';

class SettingsDialogShell extends StatelessWidget {
  const SettingsDialogShell({
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 640,
    this.maxHeight = 560,
    this.minHorizontalInset = 20,
    this.minVerticalInset = 24,
    this.radius = 24,
    this.horizontalPadding = 20,
    this.topContentPadding = 8,
    this.bottomActionPadding = 12,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final double maxHeight;
  final double minHorizontalInset;
  final double minVerticalInset;
  final double radius;
  final double horizontalPadding;
  final double topContentPadding;
  final double bottomActionPadding;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double targetWidth =
        (screenWidth - (minHorizontalInset * 2)).clamp(280.0, maxWidth);
    final ThemeData baseTheme = Theme.of(context);
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
        constraints: BoxConstraints(maxWidth: maxWidth),
        insetPadding: EdgeInsets.symmetric(
          horizontal: minHorizontalInset,
          vertical: minVerticalInset,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        title: title,
        contentPadding: EdgeInsets.fromLTRB(
          horizontalPadding,
          topContentPadding,
          horizontalPadding,
          0,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: targetWidth,
            maxWidth: targetWidth,
            maxHeight: maxHeight,
          ),
          child: content,
        ),
        actionsPadding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          bottomActionPadding,
        ),
        actions: actions,
      ),
    );
  }
}

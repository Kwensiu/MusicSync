import 'package:flutter/material.dart';
import 'package:music_sync/app/widgets/app_dialog_shell.dart';

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
    return AppDialogShell(
      title: title,
      content: content,
      actions: actions,
      size: AppDialogSize.panel,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      minHorizontalInset: minHorizontalInset,
      minVerticalInset: minVerticalInset,
      radius: radius,
      horizontalPadding: horizontalPadding,
      topContentPadding: topContentPadding,
      bottomActionPadding: bottomActionPadding,
    );
  }
}

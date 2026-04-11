import 'package:flutter/material.dart';

class AppPageContent extends StatelessWidget {
  const AppPageContent({required this.child, this.maxWidth = 1080, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

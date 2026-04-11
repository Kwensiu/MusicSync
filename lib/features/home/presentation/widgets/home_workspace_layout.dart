import 'package:flutter/material.dart';

class HomeWorkspaceLayout extends StatefulWidget {
  const HomeWorkspaceLayout({
    required this.connectionSection,
    required this.sourceSection,
    required this.previewSection,
    required this.advancedSection,
    super.key,
  });

  static const double _pagePadding = 16;
  static const double _sectionGap = 16;

  final Widget connectionSection;
  final Widget sourceSection;
  final Widget previewSection;
  final Widget advancedSection;

  @override
  State<HomeWorkspaceLayout> createState() => _HomeWorkspaceLayoutState();
}

class _HomeWorkspaceLayoutState extends State<HomeWorkspaceLayout> {
  late final ScrollController _primaryScrollController;

  @override
  void initState() {
    super.initState();
    _primaryScrollController = ScrollController();
  }

  @override
  void dispose() {
    _primaryScrollController.dispose();
    super.dispose();
  }

  bool _isPrimaryScrollNotification(ScrollNotification notification) {
    return notification.depth == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _primaryScrollController,
      notificationPredicate: _isPrimaryScrollNotification,
      child: ListView(
        controller: _primaryScrollController,
        padding: const EdgeInsets.all(HomeWorkspaceLayout._pagePadding),
        children: <Widget>[
          widget.connectionSection,
          const SizedBox(height: HomeWorkspaceLayout._sectionGap),
          widget.sourceSection,
          const SizedBox(height: HomeWorkspaceLayout._sectionGap),
          widget.previewSection,
          const SizedBox(height: HomeWorkspaceLayout._sectionGap),
          widget.advancedSection,
        ],
      ),
    );
  }
}

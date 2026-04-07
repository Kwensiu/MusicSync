import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions = const <Widget>[],
    this.showBackButton,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton ?? canPop,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:music_sync/models/diff_item.dart';

class PlanItemList extends StatelessWidget {
  const PlanItemList({
    required this.items,
    super.key,
    this.height = 360,
  });

  final List<DiffItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final DiffItem item = items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              item.relativePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.reason == null ? null : Text(item.reason!),
            trailing: Text(item.type.name.toUpperCase()),
          );
        },
      ),
    );
  }
}

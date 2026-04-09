import 'package:flutter/material.dart';
import 'package:music_sync/app/widgets/app_dialog_shell.dart';
import 'package:music_sync/core/utils/path_display_format.dart';
import 'package:music_sync/features/home/presentation/widgets/recent_record_card/recent_record_card.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class RecentDirectoryManagerDialog extends StatefulWidget {
  const RecentDirectoryManagerDialog({
    required this.initialRecords,
    required this.onUse,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<RecentDirectoryRecord> initialRecords;
  final Future<void> Function(RecentDirectoryRecord record) onUse;
  final Future<List<RecentDirectoryRecord>> Function(
    List<RecentDirectoryRecord> records,
  ) onReorder;
  final Future<List<RecentDirectoryRecord>> Function(
    RecentDirectoryRecord record,
  ) onEdit;
  final Future<List<RecentDirectoryRecord>> Function(
    RecentDirectoryRecord record,
  ) onDelete;

  @override
  State<RecentDirectoryManagerDialog> createState() =>
      _RecentDirectoryManagerDialogState();
}

class _RecentDirectoryManagerDialogState
    extends State<RecentDirectoryManagerDialog> {
  late List<RecentDirectoryRecord> _records = widget.initialRecords;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      size: AppDialogSize.panel,
      maxWidth: 520,
      maxHeight: 560,
      title: Text(context.l10n.homeRecentDirectories),
      onClose: () => Navigator.of(context).pop(),
      topContentPadding: 4,
      bottomContentPadding: 0,
      content: SizedBox(
        height: 448,
        child: _records.isEmpty
            ? Center(child: Text(context.l10n.homeRecentEmpty))
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                proxyDecorator: (
                  Widget child,
                  int index,
                  Animation<double> animation,
                ) {
                  return child;
                },
                itemCount: _records.length,
                onReorder: (int oldIndex, int newIndex) async {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final List<RecentDirectoryRecord> next =
                      List<RecentDirectoryRecord>.from(_records);
                  final RecentDirectoryRecord item = next.removeAt(oldIndex);
                  next.insert(newIndex, item);
                  setState(() {
                    _records = next;
                  });
                  final List<RecentDirectoryRecord> refreshed =
                      await widget.onReorder(next);
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _records = refreshed;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final RecentDirectoryRecord record = _records[index];
                  return Padding(
                    key: ValueKey<String>(record.handle.entryId),
                    padding: EdgeInsets.only(
                      bottom: index == _records.length - 1 ? 0 : 8,
                    ),
                    child: RecentRecordCard(
                      title: record.label,
                      subtitle: record.note == null ||
                              record.note!.trim().isEmpty
                          ? null
                          : record.handle.displayName == record.label
                              ? formatDisplayPath(record.handle.entryId)
                              : formatDisplayPath(record.handle.displayName),
                      dragHandle: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onUse: () async {
                        Navigator.of(context).pop();
                        await widget.onUse(record);
                      },
                      onEditRecord: () async {
                        final List<RecentDirectoryRecord> refreshed =
                            await widget.onEdit(record);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _records = refreshed;
                        });
                      },
                      onDelete: () async {
                        final List<RecentDirectoryRecord> refreshed =
                            await widget.onDelete(record);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _records = refreshed;
                        });
                      },
                    ),
                  );
                },
              ),
      ),
      actions: const <Widget>[],
    );
  }
}

class RecentAddressManagerDialog extends StatefulWidget {
  const RecentAddressManagerDialog({
    required this.initialRecords,
    required this.onUse,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<RecentAddressRecord> initialRecords;
  final Future<void> Function(RecentAddressRecord record) onUse;
  final Future<List<RecentAddressRecord>> Function(
    List<RecentAddressRecord> records,
  ) onReorder;
  final Future<List<RecentAddressRecord>> Function(
    RecentAddressRecord record,
  ) onEdit;
  final Future<List<RecentAddressRecord>> Function(
    RecentAddressRecord record,
  ) onDelete;

  @override
  State<RecentAddressManagerDialog> createState() =>
      _RecentAddressManagerDialogState();
}

class _RecentAddressManagerDialogState
    extends State<RecentAddressManagerDialog> {
  late List<RecentAddressRecord> _records = widget.initialRecords;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      size: AppDialogSize.panel,
      maxWidth: 520,
      maxHeight: 560,
      title: Text(context.l10n.homeRecentAddresses),
      onClose: () => Navigator.of(context).pop(),
      topContentPadding: 4,
      bottomContentPadding: 0,
      content: SizedBox(
        height: 448,
        child: _records.isEmpty
            ? Center(child: Text(context.l10n.homeRecentEmpty))
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                proxyDecorator: (
                  Widget child,
                  int index,
                  Animation<double> animation,
                ) {
                  return child;
                },
                itemCount: _records.length,
                onReorder: (int oldIndex, int newIndex) async {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final List<RecentAddressRecord> next =
                      List<RecentAddressRecord>.from(_records);
                  final RecentAddressRecord item = next.removeAt(oldIndex);
                  next.insert(newIndex, item);
                  setState(() {
                    _records = next;
                  });
                  final List<RecentAddressRecord> refreshed =
                      await widget.onReorder(next);
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _records = refreshed;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final RecentAddressRecord record = _records[index];
                  return Padding(
                    key: ValueKey<String>(record.address),
                    padding: EdgeInsets.only(
                      bottom: index == _records.length - 1 ? 0 : 8,
                    ),
                    child: RecentRecordCard(
                      title: record.label,
                      subtitle: record.address == record.label
                          ? null
                          : record.address,
                      dragHandle: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onUse: () async {
                        Navigator.of(context).pop();
                        await widget.onUse(record);
                      },
                      onEditRecord: () async {
                        final List<RecentAddressRecord> refreshed =
                            await widget.onEdit(record);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _records = refreshed;
                        });
                      },
                      onDelete: () async {
                        final List<RecentAddressRecord> refreshed =
                            await widget.onDelete(record);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _records = refreshed;
                        });
                      },
                    ),
                  );
                },
              ),
      ),
      actions: const <Widget>[],
    );
  }
}

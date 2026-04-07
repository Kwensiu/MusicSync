import 'dart:async';

import 'package:music_sync/core/errors/sync_cancelled_exception.dart';

class SyncCancelToken {
  bool _isCancelled = false;
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _isCancelled;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _cancelled.complete();
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const SyncCancelledException();
    }
  }
}

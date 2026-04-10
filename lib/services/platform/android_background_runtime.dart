import 'dart:io';

import 'package:flutter/services.dart';

class AndroidBackgroundRuntime {
  AndroidBackgroundRuntime._();

  static const MethodChannel _channel = MethodChannel(
    'music_sync/android_runtime',
  );

  static Future<void> setKeepAliveEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'setKeepAliveEnabled',
        <String, Object?>{'enabled': enabled},
      );
    } on PlatformException {
      // Background keep-alive is best effort in this stage.
    }
  }
}

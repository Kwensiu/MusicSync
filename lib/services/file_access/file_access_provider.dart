import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/services/file_access/android_file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/windows_file_access_gateway.dart';

final Provider<FileAccessGateway> fileAccessGatewayProvider =
    Provider<FileAccessGateway>((Ref ref) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return AndroidFileAccessGateway();
        case TargetPlatform.windows:
          return WindowsFileAccessGateway();
        default:
          return WindowsFileAccessGateway();
      }
    });

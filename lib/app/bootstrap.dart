import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/app/app.dart';

void bootstrap() {
  runApp(const ProviderScope(child: MusicSyncApp()));
}

import 'dart:convert';

import 'package:music_sync/services/network/protocol/protocol_message.dart';

class ProtocolCodec {
  const ProtocolCodec();

  String encode(ProtocolMessage message) {
    return '${jsonEncode(message.toJson())}\n';
  }

  ProtocolMessage decode(String line) {
    final Object? value = jsonDecode(line);
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Invalid protocol frame.');
    }
    return ProtocolMessage.fromJson(
      value.map((Object? key, Object? data) => MapEntry(key.toString(), data)),
    );
  }
}

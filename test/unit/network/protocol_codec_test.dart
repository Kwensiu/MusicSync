import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/services/network/protocol/protocol_codec.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';

void main() {
  test('protocol codec encodes and decodes message line', () {
    const ProtocolCodec codec = ProtocolCodec();
    const ProtocolMessage message = ProtocolMessage(
      type: 'hello',
      requestId: 'req-1',
      payload: <String, Object?>{
        'device': <String, Object?>{
          'deviceId': 'desktop:44888',
          'deviceName': 'desktop',
        },
      },
    );

    final String encoded = codec.encode(message);
    final ProtocolMessage decoded = codec.decode(encoded.trim());

    expect(decoded.type, 'hello');
    expect(decoded.requestId, 'req-1');
    expect(decoded.payload['device'], isA<Map<String, Object?>>());
  });
}

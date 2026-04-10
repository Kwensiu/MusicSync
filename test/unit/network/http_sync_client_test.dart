import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/services/network/http/http_sync_client.dart';
import 'package:music_sync/services/network/http/http_sync_routes.dart';

void main() {
  group('HttpSyncClient', () {
    test('hello surfaces server error message on non-2xx response', () async {
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.hello);
        final Object? payload = jsonDecode(
          await utf8.decoder.bind(request).join(),
        );
        expect(payload, isA<Map<Object?, Object?>>());
        final Map<Object?, Object?> map = payload as Map<Object?, Object?>;
        expect(
          (map['transferProtocols'] as List<Object?>?)?.cast<String>(),
          contains('stream-v1'),
        );
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{'message': 'Remote hello failed.'}),
          );
        await request.response.close();
      });
      addTearDown(server.close);

      final HttpSyncClient client = HttpSyncClient();

      await expectLater(
        () => client.hello(
          address: InternetAddress.loopbackIPv4.address,
          port: server.port,
          localDevice: const DeviceInfo(
            deviceId: 'local',
            deviceName: 'Local',
            platform: 'windows',
            address: '127.0.0.1',
            port: 12345,
          ),
          directoryReady: true,
        ),
        throwsA(
          isA<HttpException>().having(
            (HttpException error) => error.message,
            'message',
            'Remote hello failed.',
          ),
        ),
      );
    });

    test('copyFileStream fails on non-2xx response', () async {
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.copyFileStream);
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'message': 'Transfer endpoint missing.',
            }),
          );
        await request.response.close();
      });
      addTearDown(server.close);

      final HttpSyncClient client = HttpSyncClient();

      await expectLater(
        () => client.copyFileStream(
          address: InternetAddress.loopbackIPv4.address,
          port: server.port,
          remoteRootId: 'root',
          relativePath: 'music/song.mp3',
          expectedBytes: 0,
          source: const Stream<List<int>>.empty(),
          httpEncryptionEnabled: false,
        ),
        throwsA(
          isA<HttpException>().having(
            (HttpException error) => error.message,
            'message',
            'Transfer endpoint missing.',
          ),
        ),
      );
    });

    test('copyFileStream sends binary headers and body', () async {
      final List<int> received = <int>[];
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.copyFileStream);
        expect(
          request.headers.contentType?.mimeType,
          ContentType.binary.mimeType,
        );
        expect(request.headers.value('x-remote-root-id'), 'root');
        expect(
          request.headers.value('x-relative-path'),
          Uri.encodeComponent('music/中文 song.mp3'),
        );
        expect(request.headers.value('x-file-size'), '3');
        await for (final List<int> chunk in request) {
          received.addAll(chunk);
        }
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{'ok': true}));
        await request.response.close();
      });
      addTearDown(server.close);

      final HttpSyncClient client = HttpSyncClient();
      await client.copyFileStream(
        address: InternetAddress.loopbackIPv4.address,
        port: server.port,
        remoteRootId: 'root',
        relativePath: 'music/中文 song.mp3',
        expectedBytes: 3,
        source: Stream<List<int>>.fromIterable(<List<int>>[
          <int>[1, 2],
          <int>[3],
        ]),
        httpEncryptionEnabled: false,
      );
      expect(received, <int>[1, 2, 3]);
    });

    test('entryDetail rejects payload without detail map', () async {
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.entryDetail);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{'detail': 'invalid'}));
        await request.response.close();
      });
      addTearDown(server.close);

      final HttpSyncClient client = HttpSyncClient();

      await expectLater(
        () => client.entryDetail(
          address: InternetAddress.loopbackIPv4.address,
          port: server.port,
          entryId: 'entry-1',
          httpEncryptionEnabled: false,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('entryDetail parses valid detail payload', () async {
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.entryDetail);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'detail': <String, Object?>{
                'entryId': 'entry-1',
                'displayName': 'song.mp3',
                'isDirectory': false,
                'size': 42,
                'modifiedTime': 5,
                'audioMetadata': <String, Object?>{'artist': 'Artist'},
              },
            }),
          );
        await request.response.close();
      });
      addTearDown(server.close);

      final HttpSyncClient client = HttpSyncClient();
      final DiffEntryDetailViewData detail = await client.entryDetail(
        address: InternetAddress.loopbackIPv4.address,
        port: server.port,
        entryId: 'entry-1',
        httpEncryptionEnabled: false,
      );

      expect(detail.displayName, 'song.mp3');
      expect(detail.audioMetadata?.artist, 'Artist');
    });
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  server.listen(handler);
  return server;
}

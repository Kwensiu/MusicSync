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

    test('beginCopy fails on non-2xx response', () async {
      final HttpServer server = await _startServer((HttpRequest request) async {
        expect(request.uri.path, HttpSyncRoutes.beginCopy);
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
        () => client.beginCopy(
          address: InternetAddress.loopbackIPv4.address,
          port: server.port,
          remoteRootId: 'root',
          relativePath: 'music/song.mp3',
          transferId: 'tx-1',
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

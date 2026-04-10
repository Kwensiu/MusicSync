import 'dart:convert';
import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_routes.dart';

class HttpSyncClient {
  HttpSyncClient({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<HelloResponseDto> hello({
    required String address,
    required int port,
    required DeviceInfo localDevice,
    required bool directoryReady,
    String? directoryDisplayName,
  }) async {
    final HttpClientRequest request = await _post(address, port, HttpSyncRoutes.hello);
    request.write(
      jsonEncode(
        HelloRequestDto(
          device: localDevice,
          directoryReady: directoryReady,
          directoryDisplayName: directoryDisplayName,
        ).toJson(),
      ),
    );
    final Map<String, Object?> payload = await _readJson(await request.close());
    return HelloResponseDto.fromJson(payload);
  }

  Future<DirectoryStatusResponseDto> directoryStatus({
    required String address,
    required int port,
  }) async {
    final HttpClientResponse response = await (await _get(
      address,
      port,
      HttpSyncRoutes.directoryStatus,
    )).close();
    return DirectoryStatusResponseDto.fromJson(await _readJson(response));
  }

  Future<void> closeSession({
    required String address,
    required int port,
    required String deviceId,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.sessionClose,
    );
    request.write(
      jsonEncode(SessionCloseRequestDto(deviceId: deviceId).toJson()),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<ScanResponseDto> scan({
    required String address,
    required int port,
  }) async {
    final HttpClientResponse response = await (await _get(
      address,
      port,
      HttpSyncRoutes.scan,
    )).close();
    return ScanResponseDto.fromJson(await _readJson(response));
  }

  Future<void> notifySyncSessionState({
    required String address,
    required int port,
    required bool active,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.syncSessionState,
    );
    request.write(
      jsonEncode(SyncSessionStateRequestDto(active: active).toJson()),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<void> beginCopy({
    required String address,
    required int port,
    required String remoteRootId,
    required String relativePath,
    required String transferId,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.beginCopy,
    );
    request.write(
      jsonEncode(
        BeginCopyRequestDto(
          remoteRootId: remoteRootId,
          relativePath: relativePath,
          transferId: transferId,
        ).toJson(),
      ),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<void> writeChunk({
    required String address,
    required int port,
    required String transferId,
    required List<int> chunk,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.writeChunk,
    );
    request.write(
      jsonEncode(
        WriteChunkRequestDto(
          transferId: transferId,
          data: base64Encode(chunk),
        ).toJson(),
      ),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<void> finishCopy({
    required String address,
    required int port,
    required String transferId,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.finishCopy,
    );
    request.write(
      jsonEncode(FinishCopyRequestDto(transferId: transferId).toJson()),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<void> abortCopy({
    required String address,
    required int port,
    required String transferId,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.abortCopy,
    );
    request.write(
      jsonEncode(AbortCopyRequestDto(transferId: transferId).toJson()),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<void> deleteEntry({
    required String address,
    required int port,
    required String remoteRootId,
    required String relativePath,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.deleteEntry,
    );
    request.write(
      jsonEncode(
        DeleteEntryRequestDto(
          remoteRootId: remoteRootId,
          relativePath: relativePath,
        ).toJson(),
      ),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
  }

  Future<DiffEntryDetailViewData> entryDetail({
    required String address,
    required int port,
    required String entryId,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.entryDetail,
    );
    request.write(
      jsonEncode(EntryDetailRequestDto(entryId: entryId).toJson()),
    );
    final Map<String, Object?> payload = await _readJson(await request.close());
    final Map<String, Object?> detail =
        (payload['detail'] as Map<Object?, Object?>).map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
    final Map<String, Object?>? audioMetadata =
        switch (detail['audioMetadata']) {
          final Map<Object?, Object?> raw => raw.map(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          ),
          _ => null,
        };
    return DiffEntryDetailViewData(
      entryId: detail['entryId'] as String? ?? '',
      displayName: detail['displayName'] as String? ?? '',
      isDirectory: detail['isDirectory'] as bool? ?? false,
      size: (detail['size'] as num?)?.toInt() ?? 0,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(
        (detail['modifiedTime'] as num?)?.toInt() ?? 0,
      ),
      audioMetadata: audioMetadata == null
          ? null
          : AudioMetadataViewData(
              title: audioMetadata['title'] as String?,
              artist: audioMetadata['artist'] as String?,
              album: audioMetadata['album'] as String?,
              composer: audioMetadata['composer'] as String?,
              trackNumber: audioMetadata['trackNumber'] as String?,
              discNumber: audioMetadata['discNumber'] as String?,
              lyrics: audioMetadata['lyrics'] as String?,
            ),
    );
  }

  Future<HttpClientRequest> _get(
    String address,
    int port,
    String path,
  ) {
    return _httpClient.getUrl(Uri.http('$address:${_resolveControlPort(port)}', path));
  }

  Future<HttpClientRequest> _post(
    String address,
    int port,
    String path,
  ) async {
    final HttpClientRequest request = await _httpClient.postUrl(
      Uri.http('$address:${_resolveControlPort(port)}', path),
    );
    request.headers.contentType = ContentType.json;
    return request;
  }

  int _resolveControlPort(int port) => port + AppConstants.httpControlPortOffset;

  Future<Map<String, Object?>> _readJson(HttpClientResponse response) async {
    final String body = await utf8.decoder.bind(response).join();
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('HTTP JSON payload invalid.');
    }
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
}

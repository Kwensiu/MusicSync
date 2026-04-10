import 'dart:convert';
import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_routes.dart';

class HttpSyncClient {
  HttpSyncClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<HelloResponseDto> hello({
    required String address,
    required int port,
    required DeviceInfo localDevice,
    required bool directoryReady,
    String? directoryDisplayName,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.hello,
    );
    request.write(
      jsonEncode(
        HelloRequestDto(
          device: localDevice,
          directoryReady: directoryReady,
          directoryDisplayName: directoryDisplayName,
        ).toJson(),
      ),
    );
    final Map<String, Object?> payload = await _readJsonResponse(
      await request.close(),
    );
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
    return DirectoryStatusResponseDto.fromJson(
      await _readJsonResponse(response),
    );
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
    await _drainSuccessResponse(await request.close());
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
    return ScanResponseDto.fromJson(await _readJsonResponse(response));
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
    await _drainSuccessResponse(await request.close());
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
    await _drainSuccessResponse(await request.close());
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
    await _drainSuccessResponse(await request.close());
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
    await _drainSuccessResponse(await request.close());
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
    await _drainSuccessResponse(await request.close());
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
    await _drainSuccessResponse(await request.close());
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
    request.write(jsonEncode(EntryDetailRequestDto(entryId: entryId).toJson()));
    final Map<String, Object?> payload = await _readJsonResponse(
      await request.close(),
    );
    final Map<String, Object?> detail = _requireMap(payload, 'detail');
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

  Future<HttpClientRequest> _get(String address, int port, String path) {
    return _httpClient.getUrl(
      Uri.http('$address:${_resolveControlPort(port)}', path),
    );
  }

  Future<HttpClientRequest> _post(String address, int port, String path) async {
    final HttpClientRequest request = await _httpClient.postUrl(
      Uri.http('$address:${_resolveControlPort(port)}', path),
    );
    request.headers.contentType = ContentType.json;
    return request;
  }

  int _resolveControlPort(int port) =>
      port + AppConstants.httpControlPortOffset;

  Future<void> _drainSuccessResponse(HttpClientResponse response) async {
    final String body = await _readResponseBody(response);
    _throwIfErrorResponse(response, body);
  }

  Future<Map<String, Object?>> _readJsonResponse(
    HttpClientResponse response,
  ) async {
    final String body = await _readResponseBody(response);
    _throwIfErrorResponse(response, body);
    return _decodeJsonMap(body);
  }

  Future<String> _readResponseBody(HttpClientResponse response) {
    return utf8.decoder.bind(response).join();
  }

  void _throwIfErrorResponse(HttpClientResponse response, String body) {
    final int statusCode = response.statusCode;
    if (statusCode >= HttpStatus.ok &&
        statusCode < HttpStatus.multipleChoices) {
      return;
    }
    final String? message = _tryReadErrorMessage(body);
    throw HttpException(
      message ??
          'HTTP ${response.statusCode} ${response.reasonPhrase ?? 'request failed'}',
    );
  }

  String? _tryReadErrorMessage(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final Map<String, Object?> payload = _decodeJsonMap(body);
      final Object? message = payload['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Map<String, Object?> _decodeJsonMap(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('HTTP JSON payload invalid.');
    }
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  Map<String, Object?> _requireMap(Map<String, Object?> payload, String key) {
    final Object? value = payload[key];
    if (value is! Map<Object?, Object?>) {
      throw FormatException('HTTP JSON payload missing valid "$key" map.');
    }
    return value.map(
      (Object? nestedKey, Object? nestedValue) =>
          MapEntry(nestedKey.toString(), nestedValue),
    );
  }

  Future<Map<String, Object?>> _readJson(HttpClientResponse response) async {
    final String body = await _readResponseBody(response);
    return _decodeJsonMap(body);
  }
}

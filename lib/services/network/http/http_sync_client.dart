import 'dart:convert';
import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_routes.dart';

class HttpSyncClient {
  // TODO(http-fingerprint): replace the current permissive self-signed
  // certificate acceptance with fingerprint pinning. This needs to work for
  // the initial hello request, all follow-up requests, and manual connections
  // that do not have discovery metadata yet.
  HttpSyncClient({HttpClient? httpClient})
    : _httpClient =
          httpClient ??
          (HttpClient()
            ..badCertificateCallback = (X509Certificate _, String _, int _) =>
                true);

  final HttpClient _httpClient;

  Future<HelloResponseDto> hello({
    required String address,
    required int port,
    required DeviceInfo localDevice,
    required bool directoryReady,
    String? directoryDisplayName,
  }) async {
    final HelloRequestDto dto = HelloRequestDto(
      device: localDevice,
      directoryReady: directoryReady,
      directoryDisplayName: directoryDisplayName,
    );
    for (final bool useHttps in <bool>[true, false]) {
      try {
        final HttpClientRequest request = await _post(
          address,
          port,
          HttpSyncRoutes.hello,
          useHttps: useHttps,
        );
        request.write(jsonEncode(dto.toJson()));
        final Map<String, Object?> payload = await _readJsonResponse(
          await request.close(),
        );
        return HelloResponseDto.fromJson(payload);
      } on HandshakeException {
        continue;
      } on SocketException {
        if (useHttps) {
          continue;
        }
        rethrow;
      }
    }
    throw const SocketException('Unable to connect over HTTP or HTTPS.');
  }

  Future<DirectoryStatusResponseDto> directoryStatus({
    required String address,
    required int port,
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientResponse response = await (await _get(
      address,
      port,
      HttpSyncRoutes.directoryStatus,
      useHttps: httpEncryptionEnabled,
    )).close();
    return DirectoryStatusResponseDto.fromJson(
      await _readJsonResponse(response),
    );
  }

  Future<void> closeSession({
    required String address,
    required int port,
    required String deviceId,
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.sessionClose,
      useHttps: httpEncryptionEnabled,
    );
    request.write(
      jsonEncode(SessionCloseRequestDto(deviceId: deviceId).toJson()),
    );
    await _drainSuccessResponse(await request.close());
  }

  Future<ScanResponseDto> scan({
    required String address,
    required int port,
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientResponse response = await (await _get(
      address,
      port,
      HttpSyncRoutes.scan,
      useHttps: httpEncryptionEnabled,
    )).close();
    return ScanResponseDto.fromJson(await _readJsonResponse(response));
  }

  Future<void> notifySyncSessionState({
    required String address,
    required int port,
    required bool active,
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.syncSessionState,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.beginCopy,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.writeChunk,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.finishCopy,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.abortCopy,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.deleteEntry,
      useHttps: httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    final HttpClientRequest request = await _post(
      address,
      port,
      HttpSyncRoutes.entryDetail,
      useHttps: httpEncryptionEnabled,
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

  Future<HttpClientRequest> _get(
    String address,
    int port,
    String path, {
    required bool useHttps,
  }) {
    return _httpClient.getUrl(
      _buildUri(address, port, path, useHttps: useHttps),
    );
  }

  Future<HttpClientRequest> _post(
    String address,
    int port,
    String path, {
    required bool useHttps,
  }) async {
    final HttpClientRequest request = await _httpClient.postUrl(
      _buildUri(address, port, path, useHttps: useHttps),
    );
    request.headers.contentType = ContentType.json;
    return request;
  }

  Uri _buildUri(
    String address,
    int port,
    String path, {
    required bool useHttps,
  }) {
    final String authority = '$address:${_resolveControlPort(port)}';
    return useHttps ? Uri.https(authority, path) : Uri.http(authority, path);
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
      message ?? 'HTTP ${response.statusCode} ${response.reasonPhrase}',
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
}

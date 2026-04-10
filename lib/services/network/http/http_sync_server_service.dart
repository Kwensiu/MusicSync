import 'dart:convert';
import 'dart:io';

import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/services/network/http/http_security_context.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_routes.dart';

typedef HelloHandler =
    Future<HelloResponseDto> Function(
      HelloRequestDto request,
      String remoteAddress,
    );
typedef SessionCloseHandler =
    Future<void> Function(SessionCloseRequestDto request);
typedef DirectoryStatusHandler = Future<DirectoryStatusResponseDto> Function();
typedef ScanHandler = Future<ScanResponseDto> Function();
typedef EntryDetailHandler =
    Future<DiffEntryDetailViewData> Function(String entryId);
typedef SyncSessionStateHandler =
    Future<void> Function(SyncSessionStateRequestDto request);
typedef BeginCopyHandler = Future<void> Function(BeginCopyRequestDto request);
typedef WriteChunkHandler = Future<void> Function(WriteChunkRequestDto request);
typedef FinishCopyHandler = Future<void> Function(FinishCopyRequestDto request);
typedef AbortCopyHandler = Future<void> Function(AbortCopyRequestDto request);
typedef DeleteEntryHandler =
    Future<void> Function(DeleteEntryRequestDto request);

class HttpSyncServerService {
  HttpSyncServerService({HttpSecurityContextStore? securityContextStore})
    : _securityContextStore =
          securityContextStore ?? HttpSecurityContextStore();

  final HttpSecurityContextStore _securityContextStore;
  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start({
    required int port,
    required bool httpEncryptionEnabled,
    required HelloHandler onHello,
    required SessionCloseHandler onSessionClose,
    required DirectoryStatusHandler onDirectoryStatus,
    required ScanHandler onScan,
    required EntryDetailHandler onEntryDetail,
    required SyncSessionStateHandler onSyncSessionState,
    required BeginCopyHandler onBeginCopy,
    required WriteChunkHandler onWriteChunk,
    required FinishCopyHandler onFinishCopy,
    required AbortCopyHandler onAbortCopy,
    required DeleteEntryHandler onDeleteEntry,
  }) async {
    await stop();
    final HttpServer server = httpEncryptionEnabled
        ? await HttpServer.bindSecure(
            InternetAddress.anyIPv4,
            port,
            (await _securityContextStore.loadOrCreate()).toSecurityContext(),
          )
        : await HttpServer.bind(InternetAddress.anyIPv4, port);
    server.listen((HttpRequest request) async {
      try {
        await _handleRequest(
          request,
          onHello: onHello,
          onSessionClose: onSessionClose,
          onDirectoryStatus: onDirectoryStatus,
          onScan: onScan,
          onEntryDetail: onEntryDetail,
          onSyncSessionState: onSyncSessionState,
          onBeginCopy: onBeginCopy,
          onWriteChunk: onWriteChunk,
          onFinishCopy: onFinishCopy,
          onAbortCopy: onAbortCopy,
          onDeleteEntry: onDeleteEntry,
        );
      } catch (error) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{'message': error.toString()}));
        await request.response.close();
      }
    });
    _server = server;
  }

  Future<void> stop() async {
    final HttpServer? server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(
    HttpRequest request, {
    required HelloHandler onHello,
    required SessionCloseHandler onSessionClose,
    required DirectoryStatusHandler onDirectoryStatus,
    required ScanHandler onScan,
    required EntryDetailHandler onEntryDetail,
    required SyncSessionStateHandler onSyncSessionState,
    required BeginCopyHandler onBeginCopy,
    required WriteChunkHandler onWriteChunk,
    required FinishCopyHandler onFinishCopy,
    required AbortCopyHandler onAbortCopy,
    required DeleteEntryHandler onDeleteEntry,
  }) async {
    switch ('${request.method} ${request.uri.path}') {
      case 'POST ${HttpSyncRoutes.hello}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        final String remoteAddress =
            request.connectionInfo?.remoteAddress.address ?? '';
        final HelloResponseDto response = await onHello(
          HelloRequestDto.fromJson(payload),
          remoteAddress,
        );
        await _writeJson(request.response, response.toJson());
        return;
      case 'POST ${HttpSyncRoutes.sessionClose}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onSessionClose(SessionCloseRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'GET ${HttpSyncRoutes.directoryStatus}':
        final DirectoryStatusResponseDto response = await onDirectoryStatus();
        await _writeJson(request.response, response.toJson());
        return;
      case 'GET ${HttpSyncRoutes.scan}':
        final ScanResponseDto response = await onScan();
        await _writeJson(request.response, response.toJson());
        return;
      case 'POST ${HttpSyncRoutes.entryDetail}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        final EntryDetailRequestDto dto = EntryDetailRequestDto.fromJson(
          payload,
        );
        final DiffEntryDetailViewData detail = await onEntryDetail(dto.entryId);
        await _writeJson(
          request.response,
          EntryDetailResponseDto(detail: detail).toJson(),
        );
        return;
      case 'POST ${HttpSyncRoutes.syncSessionState}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onSyncSessionState(SyncSessionStateRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'POST ${HttpSyncRoutes.beginCopy}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onBeginCopy(BeginCopyRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'POST ${HttpSyncRoutes.writeChunk}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onWriteChunk(WriteChunkRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'POST ${HttpSyncRoutes.finishCopy}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onFinishCopy(FinishCopyRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'POST ${HttpSyncRoutes.abortCopy}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onAbortCopy(AbortCopyRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      case 'POST ${HttpSyncRoutes.deleteEntry}':
        final Map<String, Object?> payload = await _readJsonBody(request);
        await onDeleteEntry(DeleteEntryRequestDto.fromJson(payload));
        await _writeJson(request.response, const <String, Object?>{'ok': true});
        return;
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  Future<Map<String, Object?>> _readJsonBody(HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('HTTP JSON payload invalid.');
    }
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, Object?> payload,
  ) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await response.close();
  }
}

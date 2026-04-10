import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';

class HelloRequestDto {
  const HelloRequestDto({
    required this.device,
    required this.directoryReady,
    this.directoryDisplayName,
    this.transferProtocols = const <String>[],
  });

  final DeviceInfo device;
  final bool directoryReady;
  final String? directoryDisplayName;
  final List<String> transferProtocols;

  Map<String, Object?> toJson() => <String, Object?>{
    'device': device.toJson(),
    'directoryReady': directoryReady,
    if (directoryDisplayName != null)
      'directoryDisplayName': directoryDisplayName,
    if (transferProtocols.isNotEmpty) 'transferProtocols': transferProtocols,
  };

  factory HelloRequestDto.fromJson(Map<String, Object?> json) {
    return HelloRequestDto(
      device: DeviceInfo.fromJson(_requireMap(json, 'device')),
      directoryReady: json['directoryReady'] as bool? ?? false,
      directoryDisplayName: json['directoryDisplayName'] as String?,
      transferProtocols:
          (json['transferProtocols'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }
}

class HelloResponseDto {
  const HelloResponseDto({
    required this.device,
    required this.directoryReady,
    this.directoryDisplayName,
    this.transferProtocols = const <String>[],
  });

  final DeviceInfo device;
  final bool directoryReady;
  final String? directoryDisplayName;
  final List<String> transferProtocols;

  Map<String, Object?> toJson() => <String, Object?>{
    'device': device.toJson(),
    'directoryReady': directoryReady,
    if (directoryDisplayName != null)
      'directoryDisplayName': directoryDisplayName,
    if (transferProtocols.isNotEmpty) 'transferProtocols': transferProtocols,
  };

  factory HelloResponseDto.fromJson(Map<String, Object?> json) {
    return HelloResponseDto(
      device: DeviceInfo.fromJson(_requireMap(json, 'device')),
      directoryReady: json['directoryReady'] as bool? ?? false,
      directoryDisplayName: json['directoryDisplayName'] as String?,
      transferProtocols:
          (json['transferProtocols'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }
}

class DirectoryStatusResponseDto {
  const DirectoryStatusResponseDto({
    required this.directoryReady,
    this.directoryDisplayName,
  });

  final bool directoryReady;
  final String? directoryDisplayName;

  Map<String, Object?> toJson() => <String, Object?>{
    'directoryReady': directoryReady,
    if (directoryDisplayName != null)
      'directoryDisplayName': directoryDisplayName,
  };

  factory DirectoryStatusResponseDto.fromJson(Map<String, Object?> json) {
    return DirectoryStatusResponseDto(
      directoryReady: json['directoryReady'] as bool? ?? false,
      directoryDisplayName: json['directoryDisplayName'] as String?,
    );
  }
}

class SessionCloseRequestDto {
  const SessionCloseRequestDto({required this.deviceId});

  final String deviceId;

  Map<String, Object?> toJson() => <String, Object?>{'deviceId': deviceId};

  factory SessionCloseRequestDto.fromJson(Map<String, Object?> json) {
    return SessionCloseRequestDto(deviceId: json['deviceId'] as String? ?? '');
  }
}

class SyncSessionStateRequestDto {
  const SyncSessionStateRequestDto({required this.active});

  final bool active;

  Map<String, Object?> toJson() => <String, Object?>{'active': active};

  factory SyncSessionStateRequestDto.fromJson(Map<String, Object?> json) {
    return SyncSessionStateRequestDto(active: json['active'] as bool? ?? false);
  }
}

class DeleteEntryRequestDto {
  const DeleteEntryRequestDto({
    required this.remoteRootId,
    required this.relativePath,
  });

  final String remoteRootId;
  final String relativePath;

  Map<String, Object?> toJson() => <String, Object?>{
    'remoteRootId': remoteRootId,
    'relativePath': relativePath,
  };

  factory DeleteEntryRequestDto.fromJson(Map<String, Object?> json) {
    return DeleteEntryRequestDto(
      remoteRootId: json['remoteRootId'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
    );
  }
}

class ScanResponseDto {
  const ScanResponseDto({required this.snapshot});

  final ScanSnapshot snapshot;

  Map<String, Object?> toJson() => <String, Object?>{
    'snapshot': snapshot.toJson(),
  };

  factory ScanResponseDto.fromJson(Map<String, Object?> json) {
    return ScanResponseDto(
      snapshot: ScanSnapshot.fromJson(_requireMap(json, 'snapshot')),
    );
  }
}

class EntryDetailRequestDto {
  const EntryDetailRequestDto({required this.entryId});

  final String entryId;

  Map<String, Object?> toJson() => <String, Object?>{'entryId': entryId};

  factory EntryDetailRequestDto.fromJson(Map<String, Object?> json) {
    return EntryDetailRequestDto(entryId: json['entryId'] as String? ?? '');
  }
}

class EntryDetailResponseDto {
  const EntryDetailResponseDto({required this.detail});

  final DiffEntryDetailViewData detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'detail': <String, Object?>{
      'entryId': detail.entryId,
      'displayName': detail.displayName,
      'isDirectory': detail.isDirectory,
      'size': detail.size,
      'modifiedTime': detail.modifiedTime.millisecondsSinceEpoch,
      if (detail.audioMetadata != null)
        'audioMetadata': <String, Object?>{
          if (detail.audioMetadata!.title case final String title)
            'title': title,
          if (detail.audioMetadata!.artist case final String artist)
            'artist': artist,
          if (detail.audioMetadata!.album case final String album)
            'album': album,
          if (detail.audioMetadata!.composer case final String composer)
            'composer': composer,
          if (detail.audioMetadata!.trackNumber case final String trackNumber)
            'trackNumber': trackNumber,
          if (detail.audioMetadata!.discNumber case final String discNumber)
            'discNumber': discNumber,
          if (detail.audioMetadata!.lyrics case final String lyrics)
            'lyrics': lyrics,
        },
    },
  };
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

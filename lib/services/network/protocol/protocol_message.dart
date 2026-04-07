class ProtocolMessage {
  const ProtocolMessage({
    required this.type,
    required this.requestId,
    required this.payload,
  });

  final String type;
  final String requestId;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'payload': payload,
    };
  }

  factory ProtocolMessage.fromJson(Map<String, Object?> json) {
    final Object? rawPayload = json['payload'];
    return ProtocolMessage(
      type: json['type'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      payload: rawPayload is Map<Object?, Object?>
          ? rawPayload.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            )
          : const <String, Object?>{},
    );
  }
}

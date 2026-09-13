class ExperienceRef {
  const ExperienceRef({
    required this.experienceId,
    this.experienceVersion,
    this.journeyId,
  });

  final String experienceId;
  final String? experienceVersion;
  final String? journeyId;
}

class NuxieAppAction {
  NuxieAppAction({
    required this.name,
    required this.experience,
    Map<String, Object>? payload,
  }) : payload = payload == null ? null : Map.unmodifiable(payload);

  final String name;
  final Map<String, Object>? payload;
  final ExperienceRef experience;
}

class NuxieActivityInfo {
  NuxieActivityInfo({
    required this.schemaVersion,
    required this.id,
    required this.timestampMs,
    required this.receivedAtMs,
    required this.name,
    required Map<String, Object> properties,
  }) : properties = Map.unmodifiable(properties);

  final int schemaVersion;
  final String id;
  final int timestampMs;
  final int receivedAtMs;
  final String name;
  final Map<String, Object> properties;
  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
  DateTime get receivedAt =>
      DateTime.fromMillisecondsSinceEpoch(receivedAtMs, isUtc: true);
}

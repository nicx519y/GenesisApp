import '../json_utils.dart';

class WorldHistorySettings {
  const WorldHistorySettings({
    required this.highWatermark,
    required this.lowWatermark,
    required this.storedHighWatermark,
    required this.storedLowWatermark,
    required this.source,
    required this.degraded,
  });

  factory WorldHistorySettings.fromJson(Map<String, dynamic> json) {
    return WorldHistorySettings(
      highWatermark: asInt(json['high_watermark']),
      lowWatermark: asInt(json['low_watermark']),
      storedHighWatermark: asInt(json['stored_high_watermark']),
      storedLowWatermark: asInt(json['stored_low_watermark']),
      source: asString(json['source']),
      degraded: asBool(json['degraded']),
    );
  }

  final int highWatermark;
  final int lowWatermark;
  final int storedHighWatermark;
  final int storedLowWatermark;
  final String source;
  final bool degraded;
}

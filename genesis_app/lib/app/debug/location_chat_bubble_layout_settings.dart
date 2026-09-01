import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class LocationChatBubbleLayoutSettings {
  const LocationChatBubbleLayoutSettings({
    required this.crowdedEffectiveWidthThreshold,
  });

  static const double minCrowdedEffectiveWidthThreshold = 280;
  static const double maxCrowdedEffectiveWidthThreshold = 480;
  static const double defaultCrowdedEffectiveWidthThreshold = 410;

  static const defaults = LocationChatBubbleLayoutSettings(
    crowdedEffectiveWidthThreshold: defaultCrowdedEffectiveWidthThreshold,
  );

  final double crowdedEffectiveWidthThreshold;

  LocationChatBubbleLayoutSettings copyWith({
    double? crowdedEffectiveWidthThreshold,
  }) {
    return LocationChatBubbleLayoutSettings(
      crowdedEffectiveWidthThreshold:
          crowdedEffectiveWidthThreshold ?? this.crowdedEffectiveWidthThreshold,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocationChatBubbleLayoutSettings &&
        other.crowdedEffectiveWidthThreshold == crowdedEffectiveWidthThreshold;
  }

  @override
  int get hashCode => crowdedEffectiveWidthThreshold.hashCode;
}

final locationChatBubbleLayoutSettings =
    LocationChatBubbleLayoutSettingsController();

class LocationChatBubbleLayoutSettingsController
    extends ValueNotifier<LocationChatBubbleLayoutSettings> {
  LocationChatBubbleLayoutSettingsController()
    : super(LocationChatBubbleLayoutSettings.defaults);

  static const String crowdedEffectiveWidthThresholdStorageKey =
      'developer_location_chat_crowded_effective_width_threshold_v1';

  bool _loaded = false;
  int _revision = 0;
  Future<LocationChatBubbleLayoutSettings>? _pendingLoad;

  Future<LocationChatBubbleLayoutSettings> load() {
    if (_loaded) {
      return SynchronousFuture<LocationChatBubbleLayoutSettings>(value);
    }
    final pending = _pendingLoad;
    if (pending != null) return pending;
    final load = _readStoredSettings();
    _pendingLoad = load;
    return load.whenComplete(() {
      if (identical(_pendingLoad, load)) _pendingLoad = null;
    });
  }

  Future<LocationChatBubbleLayoutSettings> _readStoredSettings() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.get(crowdedEffectiveWidthThresholdStorageKey);
      final threshold = stored is num
          ? stored.toDouble()
          : LocationChatBubbleLayoutSettings
                .defaultCrowdedEffectiveWidthThreshold;
      final loaded = LocationChatBubbleLayoutSettings(
        crowdedEffectiveWidthThreshold: threshold
            .clamp(
              LocationChatBubbleLayoutSettings
                  .minCrowdedEffectiveWidthThreshold,
              LocationChatBubbleLayoutSettings
                  .maxCrowdedEffectiveWidthThreshold,
            )
            .toDouble(),
      );
      if (revision == _revision) {
        value = loaded;
        _loaded = true;
      }
    } catch (_) {
      if (revision == _revision) _loaded = true;
    }
    return value;
  }

  void previewCrowdedEffectiveWidthThreshold(double threshold) {
    _revision += 1;
    _loaded = true;
    value = value.copyWith(
      crowdedEffectiveWidthThreshold: threshold
          .clamp(
            LocationChatBubbleLayoutSettings.minCrowdedEffectiveWidthThreshold,
            LocationChatBubbleLayoutSettings.maxCrowdedEffectiveWidthThreshold,
          )
          .toDouble(),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setDouble(
      crowdedEffectiveWidthThresholdStorageKey,
      value.crowdedEffectiveWidthThreshold,
    );
    if (!saved) {
      throw StateError('Failed to save LocationChat bubble layout settings.');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _loaded = false;
    _pendingLoad = null;
    value = LocationChatBubbleLayoutSettings.defaults;
  }
}

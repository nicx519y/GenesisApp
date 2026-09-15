import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class LocationChatBubbleLayoutSettings {
  const LocationChatBubbleLayoutSettings({
    required this.crowdedEffectiveWidthThreshold,
    this.replyViewportReserveFraction = defaultReplyViewportReserveFraction,
  });

  static const double minCrowdedEffectiveWidthThreshold = 280;
  static const double maxCrowdedEffectiveWidthThreshold = 480;
  static const double defaultCrowdedEffectiveWidthThreshold = 410;
  static const double minReplyViewportReserveFraction = 0.25;
  static const double maxReplyViewportReserveFraction = 0.9;
  static const double defaultReplyViewportReserveFraction = 0.75;

  static double normalizeReplyViewportReserveFraction(double value) =>
      value.isFinite
      ? value.clamp(
          minReplyViewportReserveFraction,
          maxReplyViewportReserveFraction,
        )
      : defaultReplyViewportReserveFraction;

  static const defaults = LocationChatBubbleLayoutSettings(
    crowdedEffectiveWidthThreshold: defaultCrowdedEffectiveWidthThreshold,
  );

  final double crowdedEffectiveWidthThreshold;
  final double replyViewportReserveFraction;

  LocationChatBubbleLayoutSettings copyWith({
    double? crowdedEffectiveWidthThreshold,
    double? replyViewportReserveFraction,
  }) {
    return LocationChatBubbleLayoutSettings(
      crowdedEffectiveWidthThreshold:
          crowdedEffectiveWidthThreshold ?? this.crowdedEffectiveWidthThreshold,
      replyViewportReserveFraction:
          replyViewportReserveFraction ?? this.replyViewportReserveFraction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocationChatBubbleLayoutSettings &&
        other.crowdedEffectiveWidthThreshold ==
            crowdedEffectiveWidthThreshold &&
        other.replyViewportReserveFraction == replyViewportReserveFraction;
  }

  @override
  int get hashCode =>
      Object.hash(crowdedEffectiveWidthThreshold, replyViewportReserveFraction);
}

final locationChatBubbleLayoutSettings =
    LocationChatBubbleLayoutSettingsController();

class LocationChatBubbleLayoutSettingsController
    extends ValueNotifier<LocationChatBubbleLayoutSettings> {
  LocationChatBubbleLayoutSettingsController()
    : super(LocationChatBubbleLayoutSettings.defaults);

  static const String crowdedEffectiveWidthThresholdStorageKey =
      'developer_location_chat_crowded_effective_width_threshold_v1';
  static const String replyViewportReserveFractionStorageKey =
      'developer_location_chat_reply_viewport_reserve_fraction_v1';

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
      final storedReserve = prefs.get(replyViewportReserveFractionStorageKey);
      final threshold = stored is num
          ? stored.toDouble()
          : LocationChatBubbleLayoutSettings
                .defaultCrowdedEffectiveWidthThreshold;
      final loaded = LocationChatBubbleLayoutSettings(
        replyViewportReserveFraction:
            LocationChatBubbleLayoutSettings.normalizeReplyViewportReserveFraction(
              storedReserve is num
                  ? storedReserve.toDouble()
                  : LocationChatBubbleLayoutSettings
                        .defaultReplyViewportReserveFraction,
            ),
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
    final reserveSaved = await prefs.setDouble(
      replyViewportReserveFractionStorageKey,
      value.replyViewportReserveFraction,
    );
    if (!saved || !reserveSaved) {
      throw StateError('Failed to save LocationChat bubble layout settings.');
    }
  }

  void previewReplyViewportReserveFraction(double fraction) {
    _revision += 1;
    _loaded = true;
    value = value.copyWith(
      replyViewportReserveFraction:
          LocationChatBubbleLayoutSettings.normalizeReplyViewportReserveFraction(
            fraction,
          ),
    );
  }

  @visibleForTesting
  void resetForTesting() {
    _revision += 1;
    _loaded = false;
    _pendingLoad = null;
    value = LocationChatBubbleLayoutSettings.defaults;
  }
}

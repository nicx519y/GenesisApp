import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class LocationChatBubbleLayoutSettings {
  const LocationChatBubbleLayoutSettings({
    required this.crowdedEffectiveWidthThreshold,
    this.replyWaitingPositioningEnabled = true,
    this.replyViewportReserveFraction = defaultReplyViewportReserveFraction,
    this.animateStreamingHeight = true,
    this.streamingTextReveal = true,
    this.streamingHeightDurationMs = 180,
    this.streamingTextDurationMs = 120,
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
  final bool replyWaitingPositioningEnabled;
  final double replyViewportReserveFraction;
  final bool animateStreamingHeight;
  final bool streamingTextReveal;
  final int streamingHeightDurationMs;
  final int streamingTextDurationMs;

  static int normalizeAnimationDuration(num value, int fallback) =>
      value.isFinite ? ((value.clamp(40, 1000) / 20).round() * 20) : fallback;

  LocationChatBubbleLayoutSettings copyWith({
    double? crowdedEffectiveWidthThreshold,
    bool? replyWaitingPositioningEnabled,
    double? replyViewportReserveFraction,
    bool? animateStreamingHeight,
    bool? streamingTextReveal,
    int? streamingHeightDurationMs,
    int? streamingTextDurationMs,
  }) {
    return LocationChatBubbleLayoutSettings(
      animateStreamingHeight:
          animateStreamingHeight ?? this.animateStreamingHeight,
      streamingTextReveal: streamingTextReveal ?? this.streamingTextReveal,
      streamingHeightDurationMs:
          streamingHeightDurationMs ?? this.streamingHeightDurationMs,
      streamingTextDurationMs:
          streamingTextDurationMs ?? this.streamingTextDurationMs,
      crowdedEffectiveWidthThreshold:
          crowdedEffectiveWidthThreshold ?? this.crowdedEffectiveWidthThreshold,
      replyWaitingPositioningEnabled:
          replyWaitingPositioningEnabled ?? this.replyWaitingPositioningEnabled,
      replyViewportReserveFraction:
          replyViewportReserveFraction ?? this.replyViewportReserveFraction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocationChatBubbleLayoutSettings &&
        other.crowdedEffectiveWidthThreshold ==
            crowdedEffectiveWidthThreshold &&
        other.replyWaitingPositioningEnabled ==
            replyWaitingPositioningEnabled &&
        other.replyViewportReserveFraction == replyViewportReserveFraction &&
        other.animateStreamingHeight == animateStreamingHeight &&
        other.streamingTextReveal == streamingTextReveal &&
        other.streamingHeightDurationMs == streamingHeightDurationMs &&
        other.streamingTextDurationMs == streamingTextDurationMs;
  }

  @override
  int get hashCode => Object.hash(
    crowdedEffectiveWidthThreshold,
    replyWaitingPositioningEnabled,
    replyViewportReserveFraction,
    animateStreamingHeight,
    streamingTextReveal,
    streamingHeightDurationMs,
    streamingTextDurationMs,
  );
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
  static const String replyWaitingPositioningEnabledStorageKey =
      'developer_location_chat_reply_waiting_positioning_enabled_v1';

  static const streamingHeightEnabledStorageKey =
      'developer_location_chat_stream_height_enabled_v1';
  static const streamingTextEnabledStorageKey =
      'developer_location_chat_stream_text_enabled_v1';
  static const streamingHeightDurationStorageKey =
      'developer_location_chat_stream_height_duration_ms_v1';
  static const streamingTextDurationStorageKey =
      'developer_location_chat_stream_text_duration_ms_v1';

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
      int duration(String key, int fallback) {
        final stored = prefs.get(key);
        return stored is num
            ? LocationChatBubbleLayoutSettings.normalizeAnimationDuration(
                stored,
                fallback,
              )
            : fallback;
      }

      bool enabled(String key) {
        final stored = prefs.get(key);
        return stored is bool ? stored : true;
      }

      final loaded = LocationChatBubbleLayoutSettings(
        replyWaitingPositioningEnabled: enabled(
          replyWaitingPositioningEnabledStorageKey,
        ),
        animateStreamingHeight: enabled(streamingHeightEnabledStorageKey),
        streamingTextReveal: enabled(streamingTextEnabledStorageKey),
        streamingHeightDurationMs: duration(
          streamingHeightDurationStorageKey,
          180,
        ),
        streamingTextDurationMs: duration(streamingTextDurationStorageKey, 120),
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
    final snapshot = value;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setDouble(
      crowdedEffectiveWidthThresholdStorageKey,
      snapshot.crowdedEffectiveWidthThreshold,
    );
    final reserveSaved = await prefs.setDouble(
      replyViewportReserveFractionStorageKey,
      snapshot.replyViewportReserveFraction,
    );
    final additionalSaved = await Future.wait([
      prefs.setBool(
        replyWaitingPositioningEnabledStorageKey,
        snapshot.replyWaitingPositioningEnabled,
      ),
      prefs.setBool(
        streamingHeightEnabledStorageKey,
        snapshot.animateStreamingHeight,
      ),
      prefs.setBool(
        streamingTextEnabledStorageKey,
        snapshot.streamingTextReveal,
      ),
      prefs.setInt(
        streamingHeightDurationStorageKey,
        snapshot.streamingHeightDurationMs,
      ),
      prefs.setInt(
        streamingTextDurationStorageKey,
        snapshot.streamingTextDurationMs,
      ),
    ]);
    if (!saved || !reserveSaved || additionalSaved.contains(false)) {
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

  void previewReplyWaitingPositioningEnabled(bool enabled) {
    _revision += 1;
    _loaded = true;
    value = value.copyWith(replyWaitingPositioningEnabled: enabled);
  }

  void previewStreamingAnimations({
    bool? heightEnabled,
    bool? textEnabled,
    double? heightDurationMs,
    double? textDurationMs,
  }) {
    _revision += 1;
    _loaded = true;
    value = value.copyWith(
      animateStreamingHeight: heightEnabled,
      streamingTextReveal: textEnabled,
      streamingHeightDurationMs: heightDurationMs == null
          ? null
          : LocationChatBubbleLayoutSettings.normalizeAnimationDuration(
              heightDurationMs,
              180,
            ),
      streamingTextDurationMs: textDurationMs == null
          ? null
          : LocationChatBubbleLayoutSettings.normalizeAnimationDuration(
              textDurationMs,
              120,
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

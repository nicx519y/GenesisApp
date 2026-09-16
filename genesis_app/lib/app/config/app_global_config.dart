import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/json_utils.dart';

typedef AppGlobalConfigLoader =
    Future<Map<String, dynamic>> Function({String? uid});

@immutable
class AppGlobalConfig {
  const AppGlobalConfig({
    this.showOpeningSheet = false,
    this.showPersonalizationForm = false,
    this.apiTraceSamplingRate = 0,
  });

  factory AppGlobalConfig.fromJson(Map<String, dynamic> json) {
    return AppGlobalConfig(
      showOpeningSheet: asBool(json['show_opening_sheet']),
      showPersonalizationForm: json['show_personalization_form'] == true,
      apiTraceSamplingRate: _samplingRate(
        json['apiTraceSamplingRate'] ?? json['api_trace_sampling_rate'],
      ),
    );
  }

  final bool showOpeningSheet;
  final bool showPersonalizationForm;
  final double apiTraceSamplingRate;
}

double _samplingRate(Object? value) {
  final parsed = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite) return 0;
  return parsed.clamp(0.0, 1.0).toDouble();
}

@immutable
class AppGlobalConfigRequestState {
  const AppGlobalConfigRequestState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  final bool isLoading;

  /// The last successful response's data, before applying client defaults.
  final Map<String, dynamic>? data;
  final Object? error;
}

class AppGlobalConfigStore extends ValueNotifier<AppGlobalConfig> {
  AppGlobalConfigStore({
    required AppGlobalConfigLoader loadConfig,
    AppGlobalConfig initialValue = const AppGlobalConfig(),
  }) : _loadConfig = loadConfig,
       super(initialValue);

  final AppGlobalConfigLoader _loadConfig;
  Future<void>? _refreshInFlight;
  final _requestState = ValueNotifier<AppGlobalConfigRequestState>(
    const AppGlobalConfigRequestState(),
  );
  bool _disposed = false;

  ValueListenable<AppGlobalConfigRequestState> get requestState =>
      _requestState;

  /// Marks the request pending immediately, including any startup UID wait.
  /// Consumers must not mistake that wait for a confirmed disabled config.
  Future<void> refresh({String? uid, Future<String?> Function()? resolveUid}) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _refresh(uid: uid, resolveUid: resolveUid);
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<void> _refresh({
    String? uid,
    Future<String?> Function()? resolveUid,
  }) async {
    final previousData = _requestState.value.data;
    _requestState.value = AppGlobalConfigRequestState(
      isLoading: true,
      data: previousData,
    );
    try {
      final resolvedUid = resolveUid == null ? uid : await resolveUid();
      if (_disposed) return;
      final data = await _loadConfig(uid: resolvedUid);
      final config = AppGlobalConfig.fromJson(data);
      if (_disposed) return;
      // Publish flags before clearing loading, so dependent feeds cannot
      // briefly observe "finished" together with the initial false defaults.
      value = config;
      _requestState.value = AppGlobalConfigRequestState(
        data: Map<String, dynamic>.unmodifiable(data),
      );
    } catch (error) {
      if (!_disposed) {
        _requestState.value = AppGlobalConfigRequestState(
          data: previousData,
          error: error,
        );
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestState.dispose();
    super.dispose();
  }
}

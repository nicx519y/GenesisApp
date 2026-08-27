import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/json_utils.dart';

@immutable
class AppGlobalConfig {
  const AppGlobalConfig({this.showOpeningSheet = false});

  factory AppGlobalConfig.fromJson(Map<String, dynamic> json) {
    return AppGlobalConfig(
      showOpeningSheet: asBool(json['show_opening_sheet']),
    );
  }

  final bool showOpeningSheet;
}

class AppGlobalConfigStore extends ValueNotifier<AppGlobalConfig> {
  AppGlobalConfigStore({
    required Future<Map<String, dynamic>> Function() loadConfig,
    AppGlobalConfig initialValue = const AppGlobalConfig(),
  }) : _loadConfig = loadConfig,
       super(initialValue);

  final Future<Map<String, dynamic>> Function() _loadConfig;
  Future<void>? _refreshInFlight;

  Future<void> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _refresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<void> _refresh() async {
    value = AppGlobalConfig.fromJson(await _loadConfig());
  }
}

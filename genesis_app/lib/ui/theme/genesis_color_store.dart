import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'genesis_color_token.dart';

class GenesisStoredColorSettings {
  const GenesisStoredColorSettings({
    required this.mode,
    required this.lightOverrides,
    required this.darkOverrides,
  });

  final ThemeMode mode;
  final Map<GenesisColorToken, Color> lightOverrides;
  final Map<GenesisColorToken, Color> darkOverrides;
}

abstract interface class GenesisColorStore {
  Future<GenesisStoredColorSettings> load();

  Future<void> save({
    required ThemeMode mode,
    required Map<GenesisColorToken, Color> lightOverrides,
    required Map<GenesisColorToken, Color> darkOverrides,
  });
}

class SharedPreferencesGenesisColorStore implements GenesisColorStore {
  const SharedPreferencesGenesisColorStore();

  static const String colorsKey = 'developer_semantic_colors_v1';
  static const String modeKey = 'developer_theme_mode_v1';

  @override
  Future<GenesisStoredColorSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final mode = switch (preferences.getString(modeKey)) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    final light = <GenesisColorToken, Color>{};
    final dark = <GenesisColorToken, Color>{};
    final encoded = preferences.getString(colorsKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, dynamic>) {
          _readPalette(decoded['light'], light);
          _readPalette(decoded['dark'], dark);
        }
      } catch (_) {
        // Invalid developer state must never prevent app startup.
      }
    }
    return GenesisStoredColorSettings(
      mode: mode,
      lightOverrides: light,
      darkOverrides: dark,
    );
  }

  @override
  Future<void> save({
    required ThemeMode mode,
    required Map<GenesisColorToken, Color> lightOverrides,
    required Map<GenesisColorToken, Color> darkOverrides,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, Object>{
      'light': _encodePalette(lightOverrides),
      'dark': _encodePalette(darkOverrides),
    });
    final colorsSaved = await preferences.setString(colorsKey, encoded);
    final modeSaved = await preferences.setString(
      modeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    if (!colorsSaved || !modeSaved) {
      throw StateError('Failed to persist developer color configuration.');
    }
  }

  static void _readPalette(
    Object? raw,
    Map<GenesisColorToken, Color> destination,
  ) {
    if (raw is! Map<String, dynamic>) return;
    for (final entry in raw.entries) {
      final token = GenesisColorToken.byId[entry.key];
      final value = entry.value;
      if (token == null || value is! int || value < 0 || value > 0xFFFFFFFF) {
        continue;
      }
      destination[token] = Color(value);
    }
  }

  static Map<String, int> _encodePalette(
    Map<GenesisColorToken, Color> overrides,
  ) {
    return <String, int>{
      for (final entry in overrides.entries)
        entry.key.id: entry.value.toARGB32(),
    };
  }
}

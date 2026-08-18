import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui_style_config.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  test('Worldo redesign theme uses the approved global color system', () {
    final theme = GenesisTheme.worldoRedesign();
    final colors = theme.extension<GenesisSemanticColors>()!;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF17151B));
    expect(colors.pageBackground, const Color(0xFF17151B));
    expect(colors.surface, const Color(0xFF17151B));
    expect(colors.surfaceRaised, const Color(0xFF1F1D24));
    expect(colors.primary, const Color(0xFFF82B3C));
    expect(colors.accentText, const Color(0xFFFF8A9A));
    expect(colors.textPrimary, Colors.white);
    expect(colors.navigationBackground, const Color(0xFF17151B));
    expect(colors.navigationSelected, Colors.white);
    expect(colors.navigationUnselected, const Color(0xFFA9A29B));
    expect(theme.textTheme.titleLarge?.color, Colors.white);
    expect(theme.textTheme.bodyMedium?.color, Colors.white);
    expect(theme.textTheme.bodySmall?.color, const Color(0xB8FFFFFF));
    expect(theme.iconTheme.color, Colors.white);
  });

  test('Worldo redesign keeps shared component metrics unchanged', () {
    final light = GenesisTheme.light().extension<GenesisUiTheme>()!;
    final redesign = GenesisTheme.worldoRedesign().extension<GenesisUiTheme>()!;

    expect(redesign.searchBorderRadius, light.searchBorderRadius);
    expect(redesign.tabIndicatorWidth, light.tabIndicatorWidth);
    expect(redesign.tabIndicatorHeight, light.tabIndicatorHeight);
    expect(redesign.panelBorderRadius, light.panelBorderRadius);
  });

  test('Worldo redesign keeps chat geometry unchanged', () {
    final light = GenesisChatTheme.light();
    final redesign = GenesisChatTheme.worldoRedesign();

    for (final pair in <(ChatUiStyleConfig, ChatUiStyleConfig)>[
      (light.standard, redesign.standard),
      (light.privateChat, redesign.privateChat),
      (light.locationChat, redesign.locationChat),
    ]) {
      expect(pair.$2.headerHeight, pair.$1.headerHeight);
      expect(pair.$2.composerPadding, pair.$1.composerPadding);
      expect(pair.$2.inputMinHeight, pair.$1.inputMinHeight);
      expect(pair.$2.messageListPadding, pair.$1.messageListPadding);
      expect(pair.$2.rowBottomPadding, pair.$1.rowBottomPadding);
      expect(pair.$2.bubblePadding, pair.$1.bubblePadding);
      expect(pair.$2.avatarSize, pair.$1.avatarSize);
    }
  });

  test('Worldo redesign registers every feature color extension', () {
    final theme = GenesisTheme.worldoRedesign();

    expect(theme.extension<GenesisChatTheme>(), isNotNull);
    expect(theme.extension<GenesisGemColors>(), isNotNull);
    expect(theme.extension<GenesisOriginColors>(), isNotNull);
    expect(theme.extension<GenesisDiscussColors>(), isNotNull);
    expect(theme.extension<GenesisCreateColors>(), isNotNull);
    expect(theme.extension<GenesisWorldColors>(), isNotNull);
    expect(theme.extension<GenesisMessageColors>(), isNotNull);
  });

  test('GenesisApp installs the Worldo redesign theme globally', () {
    final source = File('lib/app/genesis_app.dart').readAsStringSync();

    expect(source, contains('theme: GenesisTheme.worldoRedesign()'));
    expect(source, isNot(contains('theme: GenesisTheme.light()')));
  });
}

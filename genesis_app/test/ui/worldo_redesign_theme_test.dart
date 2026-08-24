import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui_style_config.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  test('Worldo dark theme keeps the approved production color system', () {
    final theme = GenesisTheme.worldoDark();
    final colors = theme.extension<GenesisSemanticColors>()!;

    expect(theme.brightness, Brightness.dark);
    // 2026-08-22 spec: Surface #151517 is the single dark ground, covering the
    // page, the bars and the map chrome. It replaced #17151B + Ink #131215.
    expect(theme.scaffoldBackgroundColor, const Color(0xFF151517));
    expect(colors.pageBackground, const Color(0xFF151517));
    expect(colors.surface, const Color(0xFF151517));
    expect(colors.surfaceRaised, const Color(0xFF1F1D24));
    expect(colors.primary, const Color(0xFFF82B3C));
    expect(colors.accentText, const Color(0xFFFF8A9A));
    expect(colors.navigationBackground, const Color(0xFF151517));
    expect(colors.navigationSelected, Colors.white);
    expect(theme.iconTheme.color, Colors.white);
  });

  test('Worldo dark theme follows the six-tier dark text ramp', () {
    final theme = GenesisTheme.worldoDark();
    final colors = theme.extension<GenesisSemanticColors>()!;

    // Pure white is reserved for bar titles; content titles and spoken lines
    // sit on soft white #F4F3F6, the 95% tier.
    expect(colors.textPrimary, const Color(0xFFF4F3F6));
    expect(colors.textHeading, const Color(0xFFF4F3F6));
    expect(colors.textStrong, const Color(0xFFF4F3F6));
    // Body, narration and chip labels: 73%.
    expect(colors.textBody, const Color(0xBAFFFFFF));
    expect(colors.textCinematic, const Color(0xBAFFFFFF));
    // Secondary lines and previews: 56%.
    expect(colors.textSecondary, const Color(0x8FFFFFFF));
    // Meta and timestamps: 45%.
    expect(colors.textTimestamp, const Color(0x73FFFFFF));
    expect(colors.textMetadata, const Color(0x73FFFFFF));
    // Idle nav and disabled: 32%.
    expect(colors.textDisabled, const Color(0x52FFFFFF));
    expect(colors.navigationUnselected, const Color(0x52FFFFFF));
    // Dividers are the 7% white rule.
    expect(colors.divider, const Color(0x12FFFFFF));
  });

  test('Worldo light theme keeps the Worldo paper ink and accent identity', () {
    final theme = GenesisTheme.worldoLight();
    final colors = theme.extension<GenesisSemanticColors>()!;

    expect(theme.brightness, Brightness.light);
    expect(colors.pageBackground, const Color(0xFFF7F5F2));
    expect(colors.surface, const Color(0xFFF7F5F2));
    expect(colors.surfaceRaised, Colors.white);
    expect(colors.primary, const Color(0xFFF82B3C));
    expect(colors.textPrimary, const Color(0xFF131215));
    expect(colors.navigationBackground, const Color(0xFFF7F5F2));
    expect(colors.navigationSelected, const Color(0xFF131215));
    expect(
      theme.extension<GenesisSkinTheme>()?.skin,
      GenesisSkin.worldoRedesign,
    );
  });

  test('Worldo redesign keeps shared component metrics unchanged', () {
    final light = GenesisTheme.worldoLight().extension<GenesisUiTheme>()!;
    final redesign = GenesisTheme.worldoDark().extension<GenesisUiTheme>()!;

    expect(redesign.searchBorderRadius, light.searchBorderRadius);
    expect(redesign.centeredAppBarHeight, light.centeredAppBarHeight);
    expect(redesign.leadingTitleAppBarHeight, light.leadingTitleAppBarHeight);
    expect(redesign.compactAppBarHeight, light.compactAppBarHeight);
    expect(redesign.searchFieldHeight, light.searchFieldHeight);
    expect(redesign.compactSearchFieldHeight, light.compactSearchFieldHeight);
    expect(redesign.regularButtonHeight, light.regularButtonHeight);
    expect(redesign.compactButtonHeight, light.compactButtonHeight);
    expect(redesign.tabIndicatorWidth, light.tabIndicatorWidth);
    expect(redesign.tabIndicatorHeight, light.tabIndicatorHeight);
    expect(redesign.panelBorderRadius, light.panelBorderRadius);
  });

  test('Worldo redesign keeps shared chat geometry unchanged', () {
    final light = GenesisChatTheme.worldoLight();
    final redesign = GenesisChatTheme.worldoDark();

    for (final pair in <(ChatUiStyleConfig, ChatUiStyleConfig)>[
      (light.standard, redesign.standard),
      (light.privateChat, redesign.privateChat),
    ]) {
      expect(pair.$2.headerHeight, pair.$1.headerHeight);
      expect(pair.$2.composerPadding, pair.$1.composerPadding);
      expect(pair.$2.inputMinHeight, pair.$1.inputMinHeight);
      expect(pair.$2.messageListPadding, pair.$1.messageListPadding);
      expect(pair.$2.rowBottomPadding, pair.$1.rowBottomPadding);
      expect(pair.$2.bubblePadding, pair.$1.bubblePadding);
      expect(pair.$2.avatarSize, pair.$1.avatarSize);
    }

    expect(redesign.locationChat.headerHeight, 54);
    expect(redesign.locationChat.inputMinHeight, 40);
    expect(
      redesign.locationChat.messageListPadding,
      light.locationChat.messageListPadding,
    );
    expect(
      redesign.locationChat.rowBottomPadding,
      light.locationChat.rowBottomPadding,
    );
    expect(redesign.locationChat.avatarSize, light.locationChat.avatarSize);
  });

  test('Worldo redesign registers every feature color extension', () {
    for (final theme in <ThemeData>[
      GenesisTheme.worldoLight(),
      GenesisTheme.worldoDark(),
    ]) {
      expect(theme.extension<GenesisChatTheme>(), isNotNull);
      expect(theme.extension<GenesisGemColors>(), isNotNull);
      expect(theme.extension<GenesisOriginColors>(), isNotNull);
      expect(theme.extension<GenesisDiscussColors>(), isNotNull);
      expect(theme.extension<GenesisCreateColors>(), isNotNull);
      expect(theme.extension<GenesisWorldColors>(), isNotNull);
      expect(theme.extension<GenesisMessageColors>(), isNotNull);
    }
  });

  test('GenesisApp installs paired Worldo themes and a theme mode', () {
    final source = File('lib/app/genesis_app.dart').readAsStringSync();

    expect(source, contains('theme: GenesisTheme.worldoLight()'));
    expect(source, contains('darkTheme: GenesisTheme.worldoDark()'));
    expect(source, contains('themeMode: themeMode'));
    expect(source, isNot(contains('GenesisTheme.light()')));
  });
}

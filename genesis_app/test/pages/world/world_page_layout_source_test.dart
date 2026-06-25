import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final worldPageSource = File('lib/pages/world/world_page.dart');

  test('world map owns identity while collapsed panel keeps only actions', () {
    final source = worldPageSource.readAsStringSync();
    final bottomHeader = source.substring(
      source.indexOf('class _WorldInfoHeader'),
      source.indexOf('enum _WorldHeaderActionKind'),
    );

    expect(source, contains('class _WorldMapIdentityPill'));
    expect(source, contains('_WorldMapIdentityPill('));
    expect(source, contains('LayoutBuilder'));
    expect(source, contains('maxIdentityWidth'));
    expect(source, isNot(contains('maxWidth: 240')));
    expect(bottomHeader, isNot(contains('GenesisPairedMetaRow')));
    expect(bottomHeader, isNot(contains('GenesisMoreActionMenuButton')));
    expect(bottomHeader, isNot(contains('_worldTitleTextStyle')));
    expect(bottomHeader, contains('StatItem'));
    expect(bottomHeader, contains('GenesisPrimaryButton'));
  });

  test('world bottom tags open single-section sheets', () {
    final source = worldPageSource.readAsStringSync();
    expect(source, contains('const _worldBottomTagItems'));
    expect(source, contains('class _WorldBottomTags'));
    expect(source, contains('class _WorldBottomTagContent'));

    final tags = source.substring(
      source.indexOf('const _worldBottomTagItems'),
      source.indexOf('class _WorldBottomTags'),
    );
    final bottomTags = source.substring(
      source.indexOf('class _WorldBottomTags'),
      source.indexOf('class _WorldBottomTagContent'),
    );
    final bottomTagContent = source.substring(
      source.indexOf('class _WorldBottomTagContent'),
      source.indexOf('class _LocationChatPanelDescriptor'),
    );
    final eventsSectionBuilder = source.substring(
      source.indexOf('Widget _buildEventsSectionPage()'),
      source.indexOf('Widget _buildStatusSectionPage()'),
    );

    expect(tags, contains("label: 'Locations'"));
    expect(tags, contains("label: 'Detail'"));
    expect(tags, contains('_worldDetailIconAsset'));
    expect(tags, contains("label: 'Events'"));
    expect(tags, contains("label: 'Status'"));
    expect(tags, contains("label: 'Cast'"));
    expect(tags, isNot(contains("label: 'Map'")));
    expect(bottomTags, contains('Color(0xFFFFFFFF)'));
    expect(bottomTags, contains('physics: const ClampingScrollPhysics()'));
    expect(bottomTags, contains('overscroll: false'));
    expect(eventsSectionBuilder, contains('ScrollConfiguration'));
    expect(eventsSectionBuilder, contains('overscroll: false'));
    expect(bottomTags, isNot(contains('TabBar(')));
    expect(source, contains('_openWorldBottomSheet('));
    expect(source, contains('enableDrag: false'));
    expect(bottomTagContent, contains('Color(0xFFEBEFF2)'));
    expect(bottomTagContent, contains('Color(0xFF666666)'));
    expect(
      bottomTagContent,
      contains('borderRadius: BorderRadius.circular(12)'),
    );
    expect(source, contains('class _WorldSingleSectionBottomSheet'));
    expect(source, contains('class _WorldSingleSectionSheetHeader'));
    expect(source, contains('onVerticalDragEnd'));
    expect(source, contains('top: 5'));
    expect(source, contains('fontSize: 16'));
    expect(source, contains('fontWeight: FontWeight.w600'));
    expect(source, contains('minimumSize: const Size(28, 28)'));
    expect(source, isNot(contains('_WorldSectionsSheetTabs')));
  });
}

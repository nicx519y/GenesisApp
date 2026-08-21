import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skin-dependent UI colors are declared by theme configuration', () {
    final violations = <String>[];
    for (final root in const <String>[
      'lib/components',
      'lib/pages',
      'lib/routers',
      'lib/ui/components',
    ]) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        final path = file.path;
        if (!path.endsWith('.dart') || _allowsPhysicalColors(path)) continue;
        final source = file.readAsStringSync().replaceAll(
          'Colors.transparent',
          '',
        );
        if (_physicalColorPattern.hasMatch(source)) violations.add(path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use GenesisSemanticColors or a feature ThemeExtension. Add an '
          'allowlist entry only for rendering/content colors with a stable '
          'reason.\n${violations.join('\n')}',
    );
  });

  test('design-system layer does not depend on app, network, or routes', () {
    final violations = <String>[];
    final forbiddenImport = RegExp(
      r'''import\s+['\"][^'\"]*(?:/app/|/network/|/routers/)[^'\"]*['\"]''',
    );
    for (final file in Directory(
      'lib/ui',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (forbiddenImport.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'The design system must remain application agnostic.\n'
          '${violations.join('\n')}',
    );
  });

  test('production pages use shared app bars and modal route helpers', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib/pages',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!path.endsWith('.dart') || path.contains('/developer_')) continue;
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final directAppBar = _directAppBarPattern.hasMatch(line);
        if (directAppBar || _directModalPattern.hasMatch(line)) {
          violations.add('$path:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Production pages must use GenesisAppBar/GenesisBackAppBar and '
          'the Genesis modal route helpers.\n${violations.join('\n')}',
    );
  });

  test('production UI does not branch layout by skin identity', () {
    final violations = <String>[];
    for (final root in const <String>['lib/components', 'lib/pages']) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains('isWorldoRedesign')) violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Worldo light and dark must share one widget structure. Theme '
          'identity may select tokens, but production UI must not branch its '
          'layout.\n${violations.join('\n')}',
    );
  });

  test('legacy GenesisTheme entrypoints are removed', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('GenesisTheme.light()') ||
          source.contains('GenesisTheme.worldoRedesign()')) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use GenesisTheme.worldoLight() and GenesisTheme.worldoDark().\n'
          '${violations.join('\n')}',
    );
  });

  test('legacy UI architecture debt cannot grow', () {
    final directUiImportFiles = <String>{};
    for (final root in const <String>['lib/components', 'lib/pages']) {
      for (final file in _dartFiles(root)) {
        if (_directUiImportPattern.hasMatch(file.readAsStringSync())) {
          directUiImportFiles.add(file.path);
        }
      }
    }

    final directPageScaffolds = _countMatches(
      _dartFiles('lib/pages'),
      _directScaffoldPattern,
    );
    final uiToFeatureImports = _countMatches(
      _dartFiles('lib/ui'),
      _uiToFeatureImportPattern,
    );
    final componentsToPagesImports = _countMatches(
      _dartFiles('lib/components'),
      _componentsToPagesImportPattern,
    );

    _expectDebtAtMost(
      name: 'files importing internal UI submodules',
      actual: directUiImportFiles.length,
      baseline: 88,
    );
    _expectDebtAtMost(
      name: 'direct Scaffold usages in pages',
      actual: directPageScaffolds,
      baseline: 26,
    );
    _expectDebtAtMost(
      name: 'lib/ui imports from feature components',
      actual: uiToFeatureImports,
      baseline: 8,
    );
    _expectDebtAtMost(
      name: 'lib/components imports from pages',
      actual: componentsToPagesImports,
      baseline: 4,
    );
  });
}

final RegExp _physicalColorPattern = RegExp(
  r'Color\s*\(\s*0x[0-9A-Fa-f]{6,8}\s*\)|\bColors\.[A-Za-z0-9_]+|GenesisColors\.|GenesisPalette\.',
);

final RegExp _directModalPattern = RegExp(
  r'\bAlertDialog\s*\(|\bshowDialog\s*(?:<[^>]+>)?\s*\(|'
  r'\bshowModalBottomSheet\s*(?:<[^>]+>)?\s*\(|'
  r'\bshowGeneralDialog\s*(?:<[^>]+>)?\s*\(',
);

final RegExp _directAppBarPattern = RegExp(
  r'(^|[\s=:])(?:const\s+)?AppBar\s*\(',
);

final RegExp _directScaffoldPattern = RegExp(
  r'(^|[\s=:])(?:const\s+)?Scaffold\s*\(',
  multiLine: true,
);

final RegExp _directUiImportPattern = RegExp(
  r'''import\s+['\"][^'\"]*ui/(?:components|theme|tokens)/''',
);

final RegExp _uiToFeatureImportPattern = RegExp(
  r'''import\s+['\"]\.\./\.\./components/''',
);

final RegExp _componentsToPagesImportPattern = RegExp(
  r'''import\s+['\"](?:\.\./)+pages/''',
);

Iterable<File> _dartFiles(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

int _countMatches(Iterable<File> files, RegExp pattern) {
  var count = 0;
  for (final file in files) {
    count += pattern.allMatches(file.readAsStringSync()).length;
  }
  return count;
}

void _expectDebtAtMost({
  required String name,
  required int actual,
  required int baseline,
}) {
  expect(
    actual,
    lessThanOrEqualTo(baseline),
    reason:
        '$name increased from the migration baseline of $baseline to '
        '$actual. Use the public UI entrypoint and preserve the dependency '
        'direction. Lower the baseline when a migration removes debt.',
  );
}

bool _allowsPhysicalColors(String path) {
  const exactPaths = <String>{
    // Light-skin and feature-theme declarations are the source of physical
    // values; consuming widgets must read their semantic roles.
    'lib/components/chat/shared/chat_ui_library.dart',
    'lib/components/chat/shared/chat_ui_style_config.dart',
    'lib/components/chat/shared/chat_ui_theme.dart',
    'lib/components/create/genesis_create_theme.dart',
    'lib/components/discuss/genesis_discuss_theme.dart',
    'lib/components/gems/gem_colors.dart',
    'lib/components/messages/genesis_message_theme.dart',
    'lib/components/origin/genesis_origin_theme.dart',
    'lib/components/world/genesis_world_theme.dart',

    // Full-screen image tools and image masks deliberately use optical black
    // and white independently of the surrounding app skin.
    'lib/components/common/genesis_generation_wait_overlay.dart',
    'lib/components/common/genesis_image_viewer_overlay.dart',
    'lib/components/common/local_image_crop_page.dart',
    'lib/pages/origin/origin_role_portrait_image_provider.dart',

    // Product/content state colors have their own meaning and are not generic
    // page surface or text colors.
    'lib/components/discuss/story_badge.dart',
    'lib/components/gems/gem_purchase_catalog.dart',
    'lib/components/home/popular_origin_list.dart',
    'lib/ui/components/recent_chat_marker.dart',

    // World-map overlays and role setup gradients are rendered content. They
    // remain feature-owned until the high-risk World/Origin migration.
    'lib/components/world_map_location_marker.dart',
    'lib/pages/world/world_page.dart',
    'lib/pages/origin/origin_world_role_setup.dart',

    // Diagnostic affordances keep fixed warning/status colors.
    'lib/components/internal_build_indicator.dart',
    'lib/components/developer_debug_floating_button.dart',
    'lib/pages/me/developer_page.dart',
    'lib/pages/me/developer_network_tab.dart',
    'lib/pages/me/developer_websocket_tab.dart',
  };
  if (exactPaths.contains(path)) return true;

  // Map paint, fog, terrain, marker and loading palettes describe rendered
  // world content rather than the surrounding application skin.
  if (path.startsWith('lib/components/tilemap/')) return true;
  if (path.startsWith('lib/components/legacy_world_map/')) return true;
  if (path == 'lib/components/world_map.dart' ||
      path == 'lib/components/world_map_contract.dart') {
    return true;
  }

  return false;
}

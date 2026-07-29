import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final tilemapDirectory = Directory('lib/components/tilemap');
  final legacyDirectory = Directory('lib/components/legacy_world_map');
  final facade = File('lib/components/world_map.dart');
  final productionPages = <File>[
    File('lib/pages/origin/origin_world_page.dart'),
    File('lib/pages/world/world_page.dart'),
  ];

  test('Tilemap and LegacyWorldMap do not import each other or the facade', () {
    final tilemapImports = _importsUnder(tilemapDirectory);
    final legacyImports = _importsUnder(legacyDirectory);

    expect(
      tilemapImports,
      isNot(anyElement(contains('legacy_world_map'))),
      reason: 'tilemap must not depend on legacy_world_map',
    );
    expect(
      legacyImports,
      isNot(anyElement(contains('/tilemap/'))),
      reason: 'legacy_world_map must not depend on tilemap',
    );
    expect(
      tilemapImports,
      isNot(anyElement(endsWith('/world_map.dart'))),
      reason: 'tilemap must not import the WorldMap facade',
    );
    expect(
      legacyImports,
      isNot(anyElement(endsWith('/world_map.dart'))),
      reason: 'legacy_world_map must not import the WorldMap facade',
    );
  });

  test('facade is the only production composition root', () {
    final facadeSource = facade.readAsStringSync();
    expect(facadeSource, contains("'tilemap/tilemap.dart'"));
    expect(facadeSource, contains("'legacy_world_map/legacy_world_map.dart'"));

    for (final page in productionPages) {
      final imports = _importsFrom(page);
      expect(
        imports,
        anyElement(endsWith('/components/world_map.dart')),
        reason: '${page.path} must import the WorldMap facade',
      );
      expect(
        imports,
        isNot(anyElement(contains('/components/tilemap/'))),
        reason: '${page.path} must not import Tilemap directly',
      );
      expect(
        imports,
        isNot(anyElement(contains('/components/legacy_world_map/'))),
        reason: '${page.path} must not import LegacyWorldMap directly',
      );
    }
  });
}

List<String> _importsUnder(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .expand(_importsFrom)
      .toList(growable: false);
}

List<String> _importsFrom(File file) {
  final importPattern = RegExp(r"^\s*import\s+'([^']+)'", multiLine: true);
  return importPattern
      .allMatches(file.readAsStringSync())
      .map((match) => match.group(1)!)
      .toList(growable: false);
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory('lib/pages/mini_phone');
  final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');

  test('production features do not share the shell private library', () {
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.contains('/preview/')) {
        continue;
      }
      final source = file.readAsStringSync();
      expect(
        RegExp(r'^part\s', multiLine: true).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      if (!file.path.endsWith('/mini_phone_page.dart')) {
        expect(
          source.contains('_MiniPhonePageState'),
          isFalse,
          reason: file.path,
        );
      }
    }
  });

  test('shared UI and session never import the phone page or entry', () {
    for (final folder in ['shared', 'session']) {
      for (final file in Directory(
        '${root.path}/$folder',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final match in directives.allMatches(file.readAsStringSync())) {
          final uri = match.group(1)!;
          expect(
            uri.endsWith('/mini_phone_page.dart') ||
                uri.endsWith('/mini_phone.dart') ||
                uri.contains('/entry/'),
            isFalse,
            reason: '${file.path}: $uri',
          );
        }
      }
    }
  });

  test('feature controllers cannot depend back on the store or UI', () {
    for (final feature in ['messages', 'posts', 'photos']) {
      final file = File(
        '${root.path}/$feature/mini_phone_${feature}_controller.dart',
      );
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        expect(
          uri.endsWith('_page.dart') ||
              uri.endsWith('/mini_phone_store.dart') ||
              uri.contains('/shared/') ||
              uri.contains('/preview/'),
          isFalse,
          reason: '${file.path}: $uri',
        );
      }
    }
  });

  test('external page integrations use only the public entry', () {
    for (final path in [
      'lib/pages/world/world_page.dart',
      'lib/pages/chat/location_chat_page.dart',
      'lib/pages/me/developer_page.dart',
    ]) {
      final imports = directives
          .allMatches(File(path).readAsStringSync())
          .map((m) => m.group(1)!)
          .where((uri) => uri.contains('/mini_phone/'));
      expect(imports, ['../mini_phone/mini_phone.dart'], reason: path);
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale has the English keys and required placeholders', () {
    final arbDir = Directory('lib/l10n');
    final english = _readArb(File('${arbDir.path}/app_en.arb'));
    final messageKeys = english.keys
        .where((key) => !key.startsWith('@'))
        .toSet();

    for (final file in arbDir.listSync().whereType<File>().where(
      (file) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(file.path),
    )) {
      final localized = _readArb(file);
      final localizedKeys = localized.keys
          .where((key) => !key.startsWith('@'))
          .toSet();
      expect(localizedKeys, messageKeys, reason: file.path);

      for (final key in messageKeys) {
        final template = localized[key] as String;
        final metadata = english['@$key'] as Map<String, dynamic>?;
        final placeholders =
            (metadata?['placeholders'] as Map<String, dynamic>?)?.keys ??
            const Iterable<String>.empty();
        for (final name in placeholders) {
          final marker = RegExp('\\{${RegExp.escape(name)}(?:,|\\})');
          expect(
            marker.hasMatch(template),
            isTrue,
            reason: '${file.path}: $key is missing {$name}',
          );
        }
      }
    }
  });
}

Map<String, dynamic> _readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

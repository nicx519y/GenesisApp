import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared UI components do not declare skin-dependent physical colors',
    () {
      const featureColorAllowlist = <String>{
        'lib/ui/components/recent_chat_marker.dart',
      };
      final componentPaths = Directory('lib/ui/components')
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.endsWith('.dart'))
          .where((path) => !featureColorAllowlist.contains(path));
      final rawColorPattern = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');

      for (final path in componentPaths) {
        final source = File(path).readAsStringSync();
        expect(
          rawColorPattern.hasMatch(source),
          isFalse,
          reason: '$path must use semantic theme roles instead of raw colors.',
        );
        expect(
          source.contains('Colors.white'),
          isFalse,
          reason: '$path must not assume a white skin.',
        );
        expect(
          source.contains('Colors.black'),
          isFalse,
          reason: '$path must not assume a black foreground.',
        );
      }
    },
  );
}

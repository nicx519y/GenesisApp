import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';

void main() {
  const supported = <Locale>[
    Locale('en'),
    Locale('zh', 'TW'),
    Locale('zh', 'CN'),
  ];

  test('prefers the exact regional locale', () {
    expect(
      resolveGenesisSupportedLocale(const Locale('zh', 'TW'), supported),
      const Locale('zh', 'TW'),
    );
    expect(
      resolveGenesisSupportedLocale(const Locale('zh', 'CN'), supported),
      const Locale('zh', 'CN'),
    );
  });

  test(
    'returns a generated locale for another region of the same language',
    () {
      expect(
        resolveGenesisSupportedLocale(const Locale('zh', 'HK'), const <Locale>[
          Locale('en'),
          Locale('zh', 'TW'),
        ]),
        const Locale('zh', 'TW'),
      );
    },
  );

  test('falls back to English for an unsupported language', () {
    expect(
      resolveGenesisSupportedLocale(const Locale('fr', 'FR'), supported),
      const Locale('en'),
    );
  });
}

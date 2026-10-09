import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_localized_rich_text.dart';

void main() {
  test('keeps a sentence whole while allowing placeholder reordering', () {
    final span = buildGenesisLocalizedTextSpan(
      template: '{worldo}を起動して、自分の{object}を作成します',
      placeholders: const {
        'worldo': TextSpan(text: '#Worldo'),
        'object': TextSpan(text: '世界'),
      },
    );

    expect(span.toPlainText(), '#Worldoを起動して、自分の世界を作成します');
    expect(span.children![0], isA<TextSpan>());
    expect((span.children![0] as TextSpan).text, '#Worldo');
    expect((span.children![2] as TextSpan).text, '世界');
  });

  test('preserves styled, clickable, and widget placeholders', () {
    final recognizer = TapGestureRecognizer();
    addTearDown(recognizer.dispose);
    const icon = SizedBox(width: 12, height: 12);

    final span = buildGenesisLocalizedTextSpan(
      template: '{icon}{amount} Gems. Read {terms}.',
      placeholders: {
        'icon': const WidgetSpan(child: icon),
        'amount': const TextSpan(
          text: '250',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        'terms': TextSpan(text: 'Terms', recognizer: recognizer),
      },
    );

    expect(span.children![0], isA<WidgetSpan>());
    expect((span.children![1] as TextSpan).style?.fontWeight, FontWeight.w700);
    expect((span.children![3] as TextSpan).recognizer, same(recognizer));
  });

  test('supports a placeholder more than once', () {
    final span = buildGenesisLocalizedTextSpan(
      template: '{name} and {name}',
      placeholders: const {'name': TextSpan(text: 'Worldo')},
    );

    expect(span.toPlainText(), 'Worldo and Worldo');
  });

  test('reports missing placeholders in debug builds', () {
    expect(
      () => buildGenesisLocalizedTextSpan(
        template: 'Hello {name}',
        placeholders: const {},
      ),
      throwsA(isA<FlutterError>()),
    );
  });

  test('reports placeholders that are not present in the template', () {
    expect(
      () => buildGenesisLocalizedTextSpan(
        template: 'Hello',
        placeholders: const {'name': TextSpan(text: 'Worldo')},
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}

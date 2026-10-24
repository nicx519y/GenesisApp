import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A852424299d4d63791e32/hook.dart'
    as hook;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/subject.dart';

void main() {
  testWidgets(
    'observes UI frame and real hit testing without dispatching back',
    (tester) async {
      final f = await mountSubject(tester);
      Future<Map<String, Object?>> read() async {
        final pending = hook.observeOperation();
        await tester.pump();
        return pending;
      }

      try {
        expect(await read(), {
          'responsive': true,
          'frameObserved': true,
          'chatVisible': true,
          'backHitTestable': true,
        });
        f.blocked.value = true;
        await tester.pump();
        expect(await read(), {
          'responsive': false,
          'frameObserved': true,
          'chatVisible': true,
          'backHitTestable': false,
        });
        f.blocked.value = false;
        await tester.pump();
        expect((await read())['responsive'], true);
        expect(f.shown.value, true);
        f.shown.value = false;
        await tester.pump();
        expect(await read(), {
          'responsive': false,
          'frameObserved': true,
          'chatVisible': false,
          'backHitTestable': false,
        });
      } finally {
        await closeSubject(tester, f);
      }
    },
  );
  test('read never accepts interaction or readiness bypass', () async {
    await expectLater(
      hook.invoke({'operation': 'interact'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read', 'prepare': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read'}, false, false),
      throwsArgumentError,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A9a3c28dfef1b22d82b51/hook.dart'
    as hook;
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart'
    show activePanel;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/subject.dart';

void main() {
  testWidgets(
    'uses actual reachable back button; blocked and absent targets reject without dispatch',
    (tester) async {
      final f = await mountSubject(tester);
      try {
        f.blocked.value = true;
        await tester.pump();
        await expectLater(
          hook.invoke({'operation': 'interact'}, false, true),
          throwsStateError,
        );
        expect(f.shown.value, true);
        f.blocked.value = false;
        await tester.pump();
        expect(await hook.invoke({'operation': 'interact'}, false, true), {
          'action': 'back',
          'dispatched': true,
        });
        await tester.pump();
        expect(activePanel(), isNull);
        await expectLater(
          hook.invoke({'operation': 'interact'}, false, true),
          throwsStateError,
        );
      } finally {
        await closeSubject(tester, f);
      }
    },
  );
  test('rejects implicit navigation and unavailable targets', () async {
    expect(() => hook.dispatchBack(null), throwsStateError);
    await expectLater(
      hook.invoke({'operation': 'read'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'interact', 'popWorld': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'interact'}, false, false),
      throwsArgumentError,
    );
  });
}

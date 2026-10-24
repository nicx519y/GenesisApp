import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart'
    as hook;
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/contract_fixture.dart';
import 'subject.dart';

void main() {
  testWidgets(
    'observes actual panel and excludes a covered or removed panel; restores owned resources',
    (tester) async {
      final f = await mountSubject(tester);
      try {
        expect(await hook.invoke({'operation': 'read'}, false, true), true);
        final cover = MaterialPageRoute<void>(builder: (_) => const Scaffold());
        f.navigator.push(cover);
        await tester.pumpAndSettle();
        expect(await hook.invoke({'operation': 'read'}, false, true), false);
        f.navigator.removeRoute(cover);
        await tester.pumpAndSettle();
        expect(await hook.invoke({'operation': 'read'}, false, true), true);
        f.shown.value = false;
        await tester.pump();
        expect(await hook.invoke({'operation': 'read'}, false, true), false);
        final restoring = f.restore('test-session');
        await tester.pump();
        expect(await restoring, {
          'restored': true,
          'matchesSnapshot': true,
          'serviceDisconnected': true,
          'resource': 'test-session',
        });
        expect(find.byType(LocationChatPanel), findsNothing);
        expect(f.previous.isCurrent, true);
        expect(() => f.blocked.addListener(() {}), throwsFlutterError);
        expect(() => f.shown.addListener(() {}), throwsFlutterError);
      } finally {
        await closeSubject(tester, f);
      }
    },
  );
  test('rejects invalid reads and Case access to contract fixture', () async {
    await expectLater(
      hook.invoke({'operation': 'prepare'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read', 'navigate': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read'}, false, false),
      throwsArgumentError,
    );
    await expectLater(
      fixture({'operation': 'prepare'}, false, true),
      throwsStateError,
    );
  });
}

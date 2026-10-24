import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A9ad73fa4984b5264a357/hook.dart'
    as hook;

void main() {
  test('rejects undeclared input before resource access', () async {
    await expectLater(
      hook.invoke({'operation': 'prepare'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read', 'foreign': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read'}, false, false),
      throwsArgumentError,
    );
  });
  test(
    'missing selection cannot manufacture a successful observation',
    () async {
      await expectLater(
        hook.invoke({'operation': 'read'}, false, true),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'entry callback and origin survive same-route card rebuild, reject another route',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      var taps = 0;
      final item = WorldListItem.fromJson({
        'info': {'world_id': 'selected', 'world_name': 'Observed'},
      });
      final d = WorldDataset(
        resource: 'r',
        owner: 'qa_test_world_r',
        currentOwner: () async => 'qa_test_world_r',
        currentResource: () => true,
        list: () async => {},
        fetch: (e, id) async => {},
      )..selectedId = 'selected';
      Widget card(Key cardKey) => GestureDetector(
        onTap: () {
          taps++;
        },
        child: WorldItemCard(key: cardKey, item: item),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: Scaffold(body: card(const ValueKey('first'))),
          ),
        );
        await tester.pump();
        final first = hook.entryCard('selected');
        expect(first, isNotNull);
        expect(hook.entryCard('foreign'), isNull);
        hook.origins[d] = ModalRoute.of(first!);
        hook.cardAction(first)!();
        expect(taps, 1);
        expect(hook.atOrigin(d), isTrue);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: Scaffold(body: card(const ValueKey('replacement'))),
          ),
        );
        await tester.pump();
        expect(hook.atOrigin(d), isTrue);
        final route = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other page')),
        );
        key.currentState!.push(route);
        await tester.pumpAndSettle();
        expect(hook.atOrigin(d), isFalse);
        key.currentState!.pop();
        await tester.pumpAndSettle();
        expect(hook.atOrigin(d), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

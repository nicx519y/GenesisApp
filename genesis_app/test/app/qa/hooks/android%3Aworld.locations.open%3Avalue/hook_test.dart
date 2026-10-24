import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.retry.preparation%253Avalue/lease.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.locations.open%253Avalue/hook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('retry resource resolves without acquiring a dataset and restores its owner', (tester) async {
    final previous = QaBridge.current;
    final store = MemoryUserSessionStore();
    await store.saveUid('before');
    final bridge = QaBridge(store, token: 'test', buildId: 'test');
    QaBridge.current = bridge;
    final lease = WorldRetryLease(bridge);
    await tester.runAsync(() async {
      try {
        await lease.prepare();
        expect(await preparedWorldId(), lease.worldId);
        // Ownership failure must not be hidden by trying another preparation.
        await store.saveUid('foreign');
        await expectLater(preparedWorldId(), throwsStateError);
        await store.saveUid(lease.uid);
        QaBridge.current = QaBridge(store, token: 'other', buildId: 'test');
        await expectLater(preparedWorldId(), throwsStateError);
      } finally {
        QaBridge.current = bridge;
        await store.saveUid(lease.uid);
        try {
          final receipt = await lease.restore();
          expect(receipt['identityRestored'], true);
          expect(receipt['worldDataRestored'], true);
          expect(receipt['requestResponseStateRestored'], true);
          expect(lease.server, null);
          expect(await store.readUid(), 'before');
          await expectLater(preparedWorldId(), throwsStateError);
        } finally {
          QaBridge.current = previous;
        }
      }
    });
  });

  for (final mode in ['enabled', 'absorbed', 'overlay', 'disabled']) {
    testWidgets('Locations touch: $mode', (tester) async {
      final rootKey = GlobalKey();
      var taps = 0;
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
          child: SizedBox(key: rootKey, width: 200, height: 100, child: Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(absorbing: mode == 'absorbed', child: TextButton(
                onPressed: mode == 'disabled' ? null : () { taps++; },
                child: const Text('Locations'),
              )),
              if (mode == 'overlay') const ModalBarrier(dismissible: false, color: Colors.transparent),
            ],
          )),
        ))));
        expect(find.text('Locations'), findsOneWidget);
        if (mode == 'enabled') {
          dispatchLocationsTap(rootKey.currentContext! as Element);
          await tester.pump();
          expect(taps, 1);
        } else {
          expect(() => dispatchLocationsTap(rootKey.currentContext! as Element), throwsStateError);
          await tester.pump();
          expect(taps, 0);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(rootKey.currentContext, null);
      }
    });
  }

  test('rejects undeclared operation before accessing App state', () async {
    await expectLater(
      invoke({'operation': 'unknown'}, false, true),
      throwsArgumentError,
    );
  });
  test(
    'rejects missing preparation instead of manufacturing an observation',
    () async {
      await expectLater(
        invoke({'operation': 'interact'}, false, true),
        throwsStateError,
      );
    },
  );
}

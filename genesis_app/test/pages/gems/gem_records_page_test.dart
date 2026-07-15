import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/gem_records.dart';
import 'package:genesis_flutter_android/pages/gems/gem_records_page.dart';

void main() {
  test('formats today record time', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 30, 9, 2)),
        now: DateTime(2026, 6, 30, 18),
      ),
      'Today 09:02',
    );
  });

  test('formats yesterday record time', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 29, 19, 20)),
        now: DateTime(2026, 6, 30, 8),
      ),
      'Yesterday 19:20',
    );
  });

  test('formats older record date', () {
    expect(
      formatGemRecordTimestamp(
        _epochSeconds(DateTime(2026, 6, 30, 9, 2)),
        now: DateTime(2026, 7, 2),
      ),
      'Jun 30, 2026',
    );
  });

  testWidgets('shows only the footer gem icon after the last page', (
    tester,
  ) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final data = Map<String, dynamic>.from(call.arguments as Map);
              clipboardText = '${data['text'] ?? ''}';
              return null;
            case 'Clipboard.getData':
              return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GemRecordsPage(
          recordsLoader: ({required scene, required pn, required rn}) async =>
              GemRecordList(
                items: const [
                  GemRecordItem(
                    ledgerId: 'ledger-1',
                    amount: 50,
                    scene: 'task',
                    reasonCode: 'daily_checkin',
                    title: 'Daily check-in',
                    subtitle: 'Daily task',
                    createdAt: 1,
                    expiresAt: 1893456000,
                  ),
                  GemRecordItem(
                    ledgerId: 'ledger-2',
                    amount: -4,
                    scene: 'world_tick',
                    reasonCode: 'location_message',
                    title: 'Message',
                    subtitle: 'Moonlit Market',
                    createdAt: 1,
                    expiresAt: 0,
                    worldName: 'Should not be used in title',
                    worldId: 'w_moonlit',
                    orderId: 'order-2',
                  ),
                ],
                total: 2,
                page: 1,
                pageSize: rn,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gem-records-footer')), findsOneWidget);
    expect(
      find.text(
        'More Gem activity will appear here after you\nearn or spend Gems.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gem-record-primary-icon')), findsNothing);
    expect(find.byKey(const ValueKey('gem-record-amount-icon')), findsNothing);
    expect(find.textContaining('Expires'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Daily check-in')).dy -
          tester.getBottomLeft(find.byType(TabBar)).dy,
      closeTo(14, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('Daily check-in')).dy -
          tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('gem-record-item-ledger-1')),
              )
              .dy,
      closeTo(2, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('+50')).dy -
          tester.getTopLeft(find.text('Daily check-in')).dy,
      closeTo(30.5, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('Message')).dy -
          tester.getTopLeft(find.text('Daily check-in')).dy,
      closeTo(102, 0.1),
    );
    final messageWorldName = tester.widget<Text>(find.text('Moonlit Market'));
    expect(messageWorldName.style?.color, const Color(0xFF999999));
    expect(find.text('ID: ledger-1'), findsOneWidget);
    expect(find.text('ID: order-2'), findsOneWidget);
    await tester.tap(find.text('ID: order-2'));
    final copied = await Clipboard.getData('text/plain');
    expect(copied?.text, 'order-2');
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('gem-record-item-ledger-1')),
          )
          .height,
      closeTo(93, 0.1),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('gem-record-item-ledger-2')),
          )
          .height,
      closeTo(93, 0.1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('gem-records-footer-icon'))),
      const Size.square(24),
    );
  });

  testWidgets('does not show the footer while another page is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GemRecordsPage(
          recordsLoader: ({required scene, required pn, required rn}) async =>
              const GemRecordList(
                items: [
                  GemRecordItem(
                    ledgerId: 'ledger-1',
                    amount: -4,
                    scene: 'world_tick',
                    reasonCode: 'message',
                    title: 'Message',
                    subtitle: 'Location chat',
                    createdAt: 1,
                    expiresAt: 0,
                  ),
                ],
                total: 2,
                page: 1,
                pageSize: 1,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gem-records-footer')), findsNothing);
  });
}

int _epochSeconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

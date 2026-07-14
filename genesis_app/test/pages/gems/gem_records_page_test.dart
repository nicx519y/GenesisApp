import 'package:flutter/material.dart';
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
                ],
                total: 1,
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

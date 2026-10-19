import 'package:flutter/widgets.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/stat_count_formatter.dart';

void main() {
  setUp(() => GenesisL10n.bind(lookupAppLocalizations(const Locale('en'))));
  test('Taiwan statistics preserve numbers and localize units', () {
    GenesisL10n.bind(lookupAppLocalizations(const Locale('zh', 'TW')));
    expect(
      formatWorldStatsLabel(
        tickNo: 1,
        subTickNo: 2,
        messageCount: 1200,
        playerCount: 3,
      ),
      '第 1-2 回合 · 1.2K 則訊息 · 3 位玩家',
    );
    expect(formatMessageCountLabel(0), '0 則訊息');
  });
  test('formatStatCount applies K M B and T suffixes', () {
    expect(formatStatCount(999), '999');
    expect(formatStatCount(1000), '1K');
    expect(formatStatCount(2300), '2.3K');
    expect(formatStatCount(4400000), '4.4M');
    expect(formatStatCount(2500000000), '2.5B');
    expect(formatStatCount(7300000000000), '7.3T');
  });

  test('formatMessageCountLabel uses singular for zero and one', () {
    expect(formatMessageCountLabel(0), '0 Message');
    expect(formatMessageCountLabel(1), '1 Message');
    expect(formatMessageCountLabel(2), '2 Messages');
    expect(formatMessageCountLabel(1200), '1.2K Messages');
  });

  test('formatWorldStatsLabel renders text-only world statistics', () {
    expect(
      formatWorldStatsLabel(
        tickNo: 4,
        subTickNo: 2,
        messageCount: 1,
        playerCount: 1200,
      ),
      'Tick 4-2 · 1 Message · 1.2K Players',
    );
    expect(
      formatWorldStatsLabel(
        tickNo: 0,
        subTickNo: 0,
        messageCount: 0,
        playerCount: 0,
      ),
      'Tick 0 · 0 Message',
    );
    expect(
      formatWorldStatsLabel(
        tickNo: 1,
        subTickNo: 0,
        messageCount: 3,
        playerCount: 1,
      ),
      'Tick 1 · 3 Messages',
    );
  });
}

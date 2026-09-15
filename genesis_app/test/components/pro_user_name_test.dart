import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/pro_membership_badge.dart';
import 'package:genesis_flutter_android/components/gems/pro_user_name.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets(
    'badges render immediately without services and preserve long-name layout',
    (tester) async {
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Column(
                  children: [
                    const SizedBox(
                      width: 140,
                      child: ProUserName(
                        membershipStatus: 1,
                        fontSize: 20,
                        child: Text(
                          'A very long name 中文名字',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Name'),
                          ProUserBadge.span(membershipStatus: 1, fontSize: 12),
                          const TextSpan(text: ': reply'),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.byType(ProMembershipBadge), findsNWidgets(2));
        final name = tester.getRect(find.text('A very long name 中文名字'));
        final badge = tester.getRect(find.byType(ProMembershipBadge).first);
        expect(badge.center.dy, closeTo(name.center.dy, 0.01));
        expect(badge.width, closeTo(24 * scale, 0.01));
        expect(badge.height, closeTo(17 * scale, 0.01));
        expect(
          badge.right,
          lessThanOrEqualTo(tester.getRect(find.byType(ProUserName)).right),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'model updates remove expired or deleted badges without reserved gaps',
    (tester) async {
      for (final value in [
        (1, false),
        (2, false),
        (0, false),
        (99, false),
        (1, true),
        (1, false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ProUserName(
                  membershipStatus: value.$1,
                  deleted: value.$2,
                  fontSize: 14,
                  child: const Text('Name', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
        );
        final active = value.$1 == 1 && !value.$2;
        expect(
          find.byType(ProMembershipBadge),
          active ? findsOneWidget : findsNothing,
        );
        if (!active) {
          expect(
            tester.getSize(find.byType(ProUserName)).width,
            tester.getSize(find.text('Name')).width,
          );
        }
      }
    },
  );
}

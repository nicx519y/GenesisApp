import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_benefit.dart';
import '../components/pro_subscription_content_test.dart' as subscription;
import '../support/membership_fixtures.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GenesisL10n.bind(lookupAppLocalizations(const Locale('zh', 'TW')));
  });
  tearDown(() => GenesisL10n.bind(lookupAppLocalizations(const Locale('en'))));

  testWidgets('Premium plan accessibility uses Taiwan billing periods', (
    tester,
  ) async {
    await tester.pumpWidget(
      subscription.page(
        () async => MembershipCatalogData(
          offers: [
            for (final yearly in [true, false])
              MembershipOffer(product: membershipProduct(yearly: yearly)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((w) => w.properties.label ?? '')
        .toList();
    expect(
      labels.any((label) => label.contains('Premium') && label.contains('每年')),
      isTrue,
    );
    expect(
      labels.any((label) => label.contains('Premium') && label.contains('每月')),
      isTrue,
    );
    expect(
      labels.any(
        (label) => label.contains(' per year') || label.contains(' per month'),
      ),
      isFalse,
    );
  });

  testWidgets(
    'English grant suffix parsing stays independent of the display locale',
    (tester) async {
      final benefits = [
        const MembershipBenefit(
          code: 'head',
          title: 'Monthly Gems',
          iconKey: 'gem',
          displayType: MembershipBenefitDisplay.included,
        ),
        const MembershipBenefit(
          code: 'grant',
          title: '2,000 Pink Gems welcome bonus',
          iconKey: 'gem',
          displayType: MembershipBenefitDisplay.included,
        ),
      ];
      await tester.pumpWidget(
        subscription.page(
          () async => MembershipCatalogData(
            offers: [
              MembershipOffer(
                product: membershipProduct(yearly: true, benefits: benefits),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('粉寶石'), findsOneWidget);
      expect(find.text('welcome bonus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_benefit.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/personalization.dart';

Map<String, dynamic> personalizationJson({
  bool completed = false,
  int genders = 5,
  int ages = 7,
}) => {
  'gender': completed ? 'g0' : '',
  'age': completed ? 'a0' : '',
  'completed': completed,
  'origin_feed_gender': '',
  'form': [
    {
      'name': 'gender',
      'label': 'Gender',
      'required': true,
      'options': [
        for (var i = 0; i < genders; i++)
          {'value': 'g$i', 'label': 'Gender $i'},
      ],
    },
    {
      'name': 'age',
      'label': 'Age',
      'required': true,
      'options': [
        for (var i = 0; i < ages; i++) {'value': 'a$i', 'label': 'Age $i'},
      ],
    },
  ],
};

PersonalizationData personalizationData({
  bool completed = false,
  int genders = 5,
  int ages = 7,
}) => PersonalizationData.fromJson(
  personalizationJson(completed: completed, genders: genders, ages: ages),
);

/// Design fixtures only. These prices and benefits are not product configuration.
Future<MembershipCatalogData> loadPersonalizationPreviewCatalog() async =>
    MembershipCatalogData(
      offers: [
        for (final yearly in [true, false])
          MembershipOffer(
            product: MembershipProduct(
              title: 'Premium',
              planCode: yearly ? 'pro_yearly' : 'pro_monthly',
              provider: MembershipProvider.google,
              storeProductId: 'developer_preview_only',
              billingMonths: yearly ? 12 : 1,
              monthlyGemsCent: 100000,
              priceCurrencyCode: 'USD',
              priceAmount: yearly ? 5999 : 999,
              benefits: const [
                MembershipBenefit(
                  code: 'preview_monthly_gems',
                  title: 'Up to 3,500 Gems Monthly',
                  iconKey: 'gem',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_story_recap',
                  title: 'Story Recap the AI Remembers beyond Memory',
                  iconKey: 'memory',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_pink_gems',
                  title: 'Free 2,000 Pink Gems per Month',
                  iconKey: 'gem',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_daily_red_gems',
                  title: 'Free 50 Extra Red Gems per Daily Check-in',
                  iconKey: 'gem',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_inspirations',
                  title: 'Unlimited Inspirations',
                  iconKey: 'inspiration',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_editing',
                  title: 'Unlimited Editing',
                  iconKey: 'edit',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_badge',
                  title: 'Exclusive Premium Badge',
                  iconKey: 'badge',
                  displayType: MembershipBenefitDisplay.enhanced,
                ),
                MembershipBenefit(
                  code: 'preview_recharge',
                  title: 'Gem Recharge',
                  iconKey: 'recharge',
                  displayType: MembershipBenefitDisplay.included,
                ),
              ],
            ),
          ),
        for (final yearly in [true, false])
          MembershipOffer(
            product: MembershipProduct(
              title: 'Deluxe',
              planCode: yearly ? 'deluxe_yearly' : 'deluxe_monthly',
              provider: MembershipProvider.google,
              storeProductId: 'developer_preview_deluxe_only',
              billingMonths: yearly ? 12 : 1,
              monthlyGemsCent: 1200000,
              priceCurrencyCode: 'USD',
              priceAmount: yearly ? 44900 : 4490,
              benefits: [
                for (final (code, title, icon) in const [
                  ('gems', 'Up to 18,000 Gems Monthly', 'gem'),
                  ('pink_gems', '12,000 Pink Gems per Month', 'gem'),
                  ('red_gems', '200 Extra Red Gems per Daily Check-in', 'gem'),
                  ('timeline', 'Timeline: every key event, in order', 'memory'),
                  ('cast', 'Cast: a living profile of everyone', 'memory'),
                  (
                    'bonds',
                    'Bonds: how everyone feels about each other',
                    'memory',
                  ),
                  ('recall', 'Characters remember all of it', 'memory'),
                  ('inspirations', 'Unlimited Inspirations', 'inspiration'),
                  ('editing', 'Unlimited Editing', 'edit'),
                  ('badge', 'Exclusive Deluxe Badge', 'badge'),
                ])
                  MembershipBenefit(
                    code: 'preview_deluxe_$code',
                    title: title,
                    iconKey: icon,
                    displayType: MembershipBenefitDisplay.enhanced,
                  ),
              ],
            ),
          ),
      ],
    );

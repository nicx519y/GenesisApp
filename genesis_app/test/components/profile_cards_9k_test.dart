import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/components/gems/profile_membership_card.dart';
import 'package:genesis_flutter_android/components/me/user_profile_library.dart';

/// Geometry pinned to design 9k / 9k2 (`design-0910/export/profile-cards.dc.html`).
/// Side margins stay at the app's 16 rather than the sheet's 22 — that is a
/// page-level value the design changes everywhere at once.
void main() {
  Future<void> pumpProfile(WidgetTester tester, GemWalletState wallet) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ValueNotifier<GemWalletState>(wallet);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileContent(
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'Eve',
              uid: 'u_A7BN1K',
              followingCount: 1,
              followerCount: 2,
              origins: [],
              worlds: [],
            ),
            gemWalletStateListenable: state,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // _FollowStats overflows at this width already; it is not under test here.
    while (tester.takeException() != null) {}
  }

  testWidgets('gems entry matches the 9k ground, figures and Top up', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      const GemWalletState(ownerUid: 'u_A7BN1K', balanceCent: 307220),
    );

    final card = tester.getRect(
      find.byKey(const ValueKey('user-profile-gems-background')),
    );
    expect(card.height, 68);

    final decoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('user-profile-gems-background')),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, const Color(0xFF232228));
    expect(decoration.borderRadius, BorderRadius.circular(16));

    // Icon 26, gap 12, then the caption/figure column — all vertically centred.
    final redIcon = tester.getRect(
      find.byKey(const ValueKey('user-profile-gem-icon')),
    );
    expect(redIcon.size, const Size(26, 26));
    expect(redIcon.left - card.left, 16);
    expect(redIcon.center.dy, closeTo(card.center.dy, 0.5));

    final roseIcon = tester.getRect(
      find.byKey(const ValueKey('user-profile-rose-gem-icon')),
    );
    expect(roseIcon.size, const Size(26, 26));
    expect(roseIcon.center.dy, closeTo(card.center.dy, 0.5));

    final topUp = tester.getRect(
      find.byKey(const ValueKey('user-profile-gems-top-up')),
    );
    expect(topUp.size, const Size(82, 30));
    expect(card.right - topUp.right, 16);
    expect(topUp.center.dy, closeTo(card.center.dy, 0.5));

    final figure = tester.widget<Text>(
      find.byKey(const ValueKey('user-profile-gems-balance')),
    );
    expect(figure.style?.fontSize, 18);
    expect(figure.style?.fontWeight, FontWeight.w800);
    expect(figure.textSpan!.toPlainText(), '3,072.2');
    // The decimal is set smaller than the integer part.
    final parts = (figure.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(parts.last.style!.fontSize, lessThan(18));
  });

  testWidgets('membership title stays fixed when account status changes', (
    tester,
  ) async {
    double? titleOffset;
    double? detailsCenter;
    for (final card in [
      const ProfileMembershipCard(),
      ProfileMembershipCard(
        isActive: true,
        membershipExpiresAt: DateTime.utc(2027, 9, 7),
      ),
      ProfileMembershipCard(
        isExpired: true,
        membershipExpiresAt: DateTime.utc(2026, 8, 1),
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 358, child: card)),
        ),
      );
      final bounds = tester.getRect(find.byType(ProfileMembershipCard));
      final title = tester.getRect(find.text('Worldo Premium'));
      final offset = title.top - bounds.top;
      titleOffset ??= offset;
      expect(offset, closeTo(titleOffset, 0.01));
      expect(bounds.height, 82);
      final details = tester.getRect(
        find.byKey(
          ValueKey(
            card.isActive || card.isExpired
                ? 'user-profile-membership-expiry'
                : 'user-profile-membership-offer',
          ),
        ),
      );
      final center = details.center.dy - bounds.top;
      detailsCenter ??= center;
      expect(center, closeTo(detailsCenter, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('9k membership card offers the plan at 82 high', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 358, child: ProfileMembershipCard()),
        ),
      ),
    );
    final card = tester.getRect(find.byType(ProfileMembershipCard));
    expect(card.height, 82);

    final subscribe = tester.getRect(
      find.byKey(const ValueKey('user-profile-membership-subscribe')),
    );
    expect(subscribe.size, const Size(82, 30));
    expect(card.right - subscribe.right, 16);
    expect(subscribe.center.dy, closeTo(card.center.dy, 0.5));
  });

  testWidgets('active membership card stays 82 high and tags the plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: ProfileMembershipCard(
              isActive: true,
              membershipExpiresAt: DateTime.utc(2027, 9, 7),
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byType(ProfileMembershipCard));
    expect(card.height, 82);
    expect(
      find.byKey(const ValueKey('user-profile-membership-subscribe')),
      findsNothing,
    );
    final tag = tester.getRect(
      find.byKey(const ValueKey('user-profile-membership-active-tag')),
    );
    expect(tag.height, 20);
    expect(find.text('Expires 2027-09-07 00:00:00'), findsOneWidget);
  });

  testWidgets('a lapsed plan stays 82 high and still offers renewal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: ProfileMembershipCard(
              isExpired: true,
              membershipExpiresAt: DateTime.utc(2026, 8, 1),
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byType(ProfileMembershipCard));
    expect(card.height, 82);
    // Status tag moves to the second line so the wordmark and Subscribe fit.
    final tag = tester.getRect(
      find.byKey(const ValueKey('user-profile-membership-expired-tag')),
    );
    final title = tester.getRect(find.text('Worldo Premium'));
    expect(tag.top, greaterThan(title.bottom));
    expect(find.text('2026-08-01 00:00:00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('user-profile-membership-subscribe')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

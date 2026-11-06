import 'package:genesis_flutter_android/components/gems/memory_membership_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/components/me/user_profile_library.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('Me prioritizes active memberships before purchase history', (
    tester,
  ) async {
    Future<void> show({
      required bool premium,
      required bool deluxe,
      required bool history,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: MemoryMembershipProfileCarousel(
                hasPurchased: history,
                premiumActive: premium,
                deluxeActive: deluxe,
                onPremiumSubscribe: () {},
                onDeluxeSubscribe: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final cards = find.byKey(const ValueKey('membership-profile-pages'));
    await show(premium: false, deluxe: false, history: true);
    final scroll = tester.widget<SingleChildScrollView>(cards).controller!;
    expect(scroll.offset, scroll.position.maxScrollExtent);
    await show(premium: true, deluxe: false, history: true);
    expect(scroll.offset, 0);
    await show(premium: false, deluxe: true, history: false);
    expect(scroll.offset, scroll.position.maxScrollExtent);
    await show(premium: true, deluxe: true, history: false);
    expect(scroll.offset, scroll.position.maxScrollExtent);

    await tester.drag(cards, const Offset(500, 0));
    await tester.pumpAndSettle();
    await show(premium: true, deluxe: false, history: true);
    await show(premium: false, deluxe: true, history: true);
    expect(scroll.offset, 0);
  });

  for (final history in [false, true]) {
    testWidgets(
      'Me short swipes snap between cards and tiny drags return, history=$history',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: MemoryMembershipProfileCarousel(
                  hasPurchased: history,
                  onPremiumSubscribe: () => taps++,
                  onDeluxeSubscribe: () => taps++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byKey(const ValueKey('membership-profile-pages'));
        final scroll = tester.widget<SingleChildScrollView>(cards).controller!;
        expect(scroll.offset, history ? scroll.position.maxScrollExtent : 0);
        // A short slow drag should complete the move without requiring the
        // previous 24px of actual movement (in addition to touch slop).
        await tester.timedDrag(
          cards,
          Offset(history ? 35 : -35, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        final destination = history ? 0.0 : scroll.position.maxScrollExtent;
        expect(scroll.offset, closeTo(destination, .01));
        await tester.timedDrag(
          cards,
          Offset(history ? -25 : 25, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(destination, .01));
        expect(taps, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final history in [false, true]) {
    testWidgets(
      'Me recognizes a fast short flick in either direction, history=$history',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: MemoryMembershipProfileCarousel(
                  hasPurchased: history,
                  onPremiumSubscribe: () => taps++,
                  onDeluxeSubscribe: () => taps++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byKey(const ValueKey('membership-profile-pages'));
        final scroll = tester.widget<SingleChildScrollView>(cards).controller!;
        // Shorter than the distance threshold after touch slop is consumed.
        await tester.fling(
          cards,
          Offset(history ? 30 : -30, 0),
          250,
          frameInterval: const Duration(milliseconds: 4),
        );
        await tester.pumpAndSettle();
        expect(
          scroll.offset,
          closeTo(history ? 0 : scroll.position.maxScrollExtent, .01),
        );
        expect(taps, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final width in [350.0, 360.0, 390.0, 430.0]) {
    testWidgets('Me uses the source membership card geometry at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
        await font.load();
      });
      GemWalletMembership membership(String plan) => GemWalletMembership(
        status: 1,
        planCode: plan,
        expiresAt: DateTime.utc(2040),
        autoRenew: true,
        blueGemsCent: 100,
      );
      final state = ValueNotifier(
        MembershipAccessState(
          status: MembershipAccessStatus.active,
          membership: membership('pro_yearly'),
          membershipDeluxe: membership('deluxe_yearly'),
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Scaffold(
            body: UserProfileContent(
              data: const UserProfileData(
                avatarUrl: '',
                displayName: 'Eve',
                uid: 'user',
                followingCount: 0,
                followerCount: 0,
                origins: [],
                worlds: [],
              ),
              membershipStateListenable: state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final premium = find.byKey(const ValueKey('membership-profile-premium'));
      final deluxe = find.byKey(const ValueKey('membership-profile-deluxe'));
      final cards = find.byKey(const ValueKey('membership-profile-pages'));
      expect(tester.getRect(deluxe).right, closeTo(width - 16, .01));
      await tester.drag(cards, const Offset(500, 0));
      await tester.pumpAndSettle();
      final premiumRect = tester.getRect(premium);
      final deluxeRect = tester.getRect(deluxe);
      final expectedWidth = (width - 104).clamp(180.0, 216.0);
      expect(premiumRect.left, 16);
      expect(premiumRect.width, expectedWidth);
      expect(deluxeRect.width, expectedWidth);
      expect(premiumRect.height, 126);
      expect(deluxeRect.height, premiumRect.height);
      expect(deluxeRect.left - premiumRect.right, 10);
      expect(deluxeRect.left, lessThan(width));
      final gems = tester.getRect(
        find.byKey(const ValueKey('user-profile-gems-background')),
      );
      expect(premiumRect.left, gems.left);
      await tester.drag(cards, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(deluxe).right, closeTo(width - 16, .01));
      expect(
        tester.getRect(premium).left,
        lessThan(tester.getRect(deluxe).left),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

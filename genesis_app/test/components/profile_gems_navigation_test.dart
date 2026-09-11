import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/user_profile_library.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  // The full profile's existing FollowStats row overflows below 439 in the
  // test font. The separate card geometry test covers its 390-wide layout.
  for (final width in [460.0, 600.0]) {
    testWidgets('Gems card routes separate hit regions at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final opened = <RouteSettings>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          onGenerateRoute: (settings) {
            opened.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: SizedBox()),
            );
          },
          home: const Scaffold(
            body: UserProfileContent(
              data: UserProfileData(
                avatarUrl: '',
                displayName: 'Eve',
                uid: 'user-1',
                followingCount: 1,
                followerCount: 2,
                origins: [],
                worlds: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
      final card = rect('user-profile-gems-background');
      final pink = rect('user-profile-pink-gems-entry');
      final topUp = rect('user-profile-gems-top-up');
      expect(pink.height, card.height);
      expect(pink.right, lessThanOrEqualTo(topUp.left - 10));

      Future<void> checkTap(Offset point, {bool subscription = false}) async {
        final previousCount = opened.length;
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(opened, hasLength(previousCount + 1));
        expect(opened.last.name, RouteNames.gemWallet);
        expect(opened.last.arguments, subscription ? 'subscription' : isNull);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }

      await checkTap(rect('user-profile-gem-icon').center);
      await checkTap(tester.getCenter(find.text('Red gems')));
      await checkTap(rect('user-profile-gems-balance').center);
      await checkTap(
        rect('user-profile-rose-gem-icon').center,
        subscription: true,
      );
      await checkTap(
        tester.getCenter(find.text('Pink gems')),
        subscription: true,
      );
      await checkTap(
        rect('user-profile-rose-gems-balance').center,
        subscription: true,
      );
      await checkTap(Offset(pink.center.dx, card.top + 2), subscription: true);
      await checkTap(
        Offset(pink.center.dx, card.bottom - 2),
        subscription: true,
      );
      await checkTap(topUp.center);
      // The empty gap is divided equally between Pink Gems and Top up.
      await checkTap(Offset(topUp.left - 5, card.center.dy));
      final rightBoundary = (pink.right + topUp.left) / 2;
      await checkTap(
        Offset(rightBoundary - 1, card.center.dy),
        subscription: true,
      );
      await checkTap(Offset(rightBoundary + 1, card.center.dy));
      final red = rect(
        'user-profile-gems-balance',
      ).expandToInclude(tester.getRect(find.text('Red gems')));
      final leftBoundary = (red.right + pink.left) / 2;
      await checkTap(Offset(leftBoundary - 1, card.center.dy));
      await checkTap(
        Offset(leftBoundary + 1, card.center.dy),
        subscription: true,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

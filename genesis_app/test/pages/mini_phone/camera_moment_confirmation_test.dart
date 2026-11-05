import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera_moment_confirmation.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';

void main() {
  const scope = 'test-env:user-1';
  const pref = 'camera-moment-confirmation:$scope';
  Future<void> launch(
    WidgetTester tester,
    ValueChanged<bool> onResult, {
    String owner = scope,
    bool forceShow = false,
    int? priceCent,
    bool recovering = false,
    bool? cameraFreeAvailable,
    Future<int> Function()? loadPrice,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await confirmCameraMoment(
                  context,
                  preferenceScope: owner,
                  forceShow: forceShow,
                  priceCent: priceCent,
                  loadPrice: loadPrice,
                  recovering: recovering,
                  cameraFreeAvailable: cameraFreeAvailable,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('chat price loads only in sheet and never blocks Generate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final price = Completer<int>();
    var reads = 0;
    bool? result;
    Future<int> load() {
      reads++;
      return price.future;
    }

    await launch(tester, (v) => result = v, loadPrice: load);
    expect(reads, 1);
    expect(find.text('Base price: — Gems'), findsOneWidget);
    await tester.tap(find.text('Generate photo'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(price.isCompleted, false);
    result = null;
    await launch(tester, (v) => result = v, loadPrice: load);
    expect(result, true);
    expect(reads, 1);
    expect(find.byType(BottomSheet), findsNothing);
    price.completeError(Exception('late price failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat preserves an existing remembered confirmation without price lookup',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'chat-photo-confirmation-v1:$scope': 3000,
      });
      var reads = 0;
      bool? result;
      await launch(
        tester,
        (v) => result = v,
        loadPrice: () async {
          reads++;
          return 5000;
        },
      );
      expect(result, true);
      expect(reads, 0);
    },
  );

  testWidgets('chat price fills in after sheet opens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final price = Completer<int>();
    await launch(tester, (_) {}, loadPrice: () => price.future);
    price.complete(1234);
    await tester.pumpAndSettle();
    expect(find.text('Base price: 12.3 Gems'), findsOneWidget);
    await tester.tap(find.text('Generate photo'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'camera confirmation isolates chat preference and reconfirms free status',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        pref: true,
        'chat-photo-confirmation-v1:$scope': 3000,
      });
      bool? confirmed;
      await launch(
        tester,
        (v) => confirmed = v,
        priceCent: 3000,
        cameraFreeAvailable: true,
      );
      expect(confirmed, isNull);
      expect(
        find.text(
          'Your first photo is currently free. Eligibility is confirmed when you submit.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Generate photo'));
      await tester.pumpAndSettle();
      expect(confirmed, true);
      confirmed = null;
      await launch(
        tester,
        (v) => confirmed = v,
        priceCent: 3000,
        cameraFreeAvailable: true,
      );
      expect(confirmed, true);
      confirmed = null;
      await launch(
        tester,
        (v) => confirmed = v,
        priceCent: 3000,
        cameraFreeAvailable: false,
      );
      expect(confirmed, isNull);
      expect(find.text('Generate photo'), findsOneWidget);
      await tester.tap(find.text('Generate photo'));
      await tester.pumpAndSettle();
      await launch(
        tester,
        (v) => confirmed = v,
        priceCent: 3100,
        cameraFreeAvailable: false,
      );
      expect(find.text('Base price: 31.0 Gems'), findsOneWidget);
    },
  );

  testWidgets(
    'live price confirmation ignores preview preference and reconfirms changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({pref: true});
      bool? confirmed;
      await launch(tester, (value) => confirmed = value, priceCent: 3000);
      expect(find.text('Base price: 30.0 Gems'), findsOneWidget);
      expect(find.text('Free trial'), findsNothing);
      await tester.tap(find.text('Generate photo'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      confirmed = null;
      await launch(tester, (value) => confirmed = value, priceCent: 3000);
      expect(confirmed, isTrue);
      await launch(tester, (value) => confirmed = value, priceCent: 3100);
      expect(find.text('Base price: 31.0 Gems'), findsOneWidget);
      await tester.tap(find.text('Generate photo'));
      await tester.pumpAndSettle();
      await launch(
        tester,
        (value) => confirmed = value,
        priceCent: 3100,
        recovering: true,
      );
      expect(find.text('Check previous request'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('camera-moment-remember')),
        findsNothing,
      );
      expect((await SharedPreferences.getInstance()).getBool(pref), isTrue);
    },
  );

  testWidgets('camera can preview remembered explanation and revoke skip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({pref: true});
    bool? confirmed;
    await launch(tester, (value) => confirmed = value, forceShow: true);
    expect(
      find.byKey(const ValueKey('camera-moment-remember')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('camera-moment-remember')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free trial'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(pref), isNull);
  });

  testWidgets('first confirmation can be remembered for this account only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    bool? confirmed;
    await launch(tester, (value) => confirmed = value);
    expect(
      find.byKey(const ValueKey('camera-moment-remember')),
      findsOneWidget,
    );
    await tester.tap(find.text('Free trial'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(pref), isTrue);
    confirmed = null;
    await launch(tester, (value) => confirmed = value);
    expect(confirmed, isTrue);
    expect(find.byKey(const ValueKey('camera-moment-remember')), findsNothing);
    await launch(
      tester,
      (value) => confirmed = value,
      owner: 'test-env:user-2',
    );
    expect(
      find.byKey(const ValueKey('camera-moment-remember')),
      findsOneWidget,
    );
  });

  testWidgets('confirmation without remembering does not persist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    bool? confirmed;
    await launch(tester, (value) => confirmed = value);
    await tester.tap(find.byKey(const ValueKey('camera-moment-remember')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free trial'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(pref), isNull);
  });

  testWidgets('explanation centers title and shows free price with white check', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await launch(tester, (_) {});
    expect(tester.getCenter(find.text('Capture this moment')).dx, 195);
    final price = find.text('30 0 Gems / photo');
    expect(price, findsOneWidget);
    final priceText = tester.widget<Text>(price);
    final original = (priceText.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .firstWhere((span) => span.text == '30');
    expect(original.style!.decoration, TextDecoration.lineThrough);
    expect(original.style!.decorationColor, miniTertiary);
    expect(original.style!.color, miniTertiary);
    expect(priceText.style!.fontSize, 12);
    expect(
      tester
              .getTopLeft(
                find.text('Turn this scene into a photo with your characters.'),
              )
              .dy -
          tester.getBottomLeft(find.text('Capture this moment')).dy,
      closeTo(12, .01),
    );
    expect(find.text('Free trial'), findsOneWidget);
    expect(
      find.text(
        'Don’t ask next time. Tap the camera to generate a photo directly.',
      ),
      findsOneWidget,
    );
    final check = find.byKey(const ValueKey('camera-moment-checkbox'));
    expect(tester.getSize(check), const Size.square(14));
    final decoration =
        tester.widget<Container>(check).decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.shape, BoxShape.circle);
    expect(
      tester
              .getTopLeft(
                find.text(
                  'Don’t ask next time. Tap the camera to generate a photo directly.',
                ),
              )
              .dx -
          tester.getTopRight(check).dx,
      closeTo(6, .01),
    );
    final trial = tester.widget<GenesisPrimaryButton>(
      find.byType(GenesisPrimaryButton),
    );
    expect(trial.height, 40);
    expect(trial.fontSize, 14);
    expect(trial.backgroundColor, const Color(0xFFFF2442));
    final icon = trial.leadingIcon! as SvgPicture;
    expect((icon.bytesLoader as SvgAssetLoader).assetName, cameraIconAsset);
    expect(icon.width, 16);
    expect(icon.height, 16);
    final sheet = find
        .ancestor(
          of: find.byKey(const ValueKey('camera-moment-price')),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(sheet).height, lessThanOrEqualTo(520));
    expect(tester.takeException(), isNull);
  });

  testWidgets('remember row toggles from its edge and accessibility action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    try {
      await launch(tester, (_) {});
      final row = find.byKey(const ValueKey('camera-moment-remember'));
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          label:
              'Don’t ask next time. Tap the camera to generate a photo directly.',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tapAt(tester.getTopRight(row) + const Offset(-2, 2));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(row).flagsCollection.isChecked,
        CheckedState.isFalse,
      );
      tester
          .getSemantics(row)
          .owner!
          .performAction(tester.getSemantics(row).id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(row).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(find.text('Free trial'));
      await tester.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getBool(pref), isTrue);
    } finally {
      semantics.dispose();
    }
  });
}

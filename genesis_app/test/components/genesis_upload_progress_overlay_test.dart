import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_upload_progress_overlay.dart';

void main() {
  testWidgets(
    'wallpaper mask clears from bottom to top without numbers or spinner',
    (tester) async {
      Future<void> show(double progress) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 190,
              height: 380,
              child: GenesisUploadProgressOverlay(
                progress: progress,
                showIndicator: false,
                revealFromBottom: true,
                animationDuration: const Duration(milliseconds: 180),
              ),
            ),
          ),
        ),
      );
      await show(0);
      final overlay = find.byType(GenesisUploadProgressOverlay);
      final mask = find.descendant(
        of: overlay,
        matching: find.byType(ColoredBox),
      );
      final bounds = tester.getRect(overlay);
      expect(tester.getRect(mask), bounds);
      expect(tester.widget<ColoredBox>(mask).color, const Color(0x7A000000));
      expect(
        find.descendant(of: overlay, matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await show(.5);
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getRect(mask).top, bounds.top);
      expect(tester.getRect(mask).height, bounds.height / 2);
      await show(1);
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getSize(mask).height, 0);
      await show(0);
      expect(tester.getRect(mask), bounds);
    },
  );

  testWidgets(
    'other callers retain the existing numeric and processing indicators',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: GenesisUploadProgressOverlay(progress: .5),
          ),
        ),
      );
      expect(find.text('50%'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: GenesisUploadProgressOverlay(progress: .5, processing: true),
          ),
        ),
      );
      expect(find.text('50%'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

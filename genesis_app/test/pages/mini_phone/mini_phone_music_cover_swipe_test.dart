import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_cover_swipe.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_widgets.dart';

void main() {
  final tracks = [
    for (var i = 0; i < 3; i++)
      MusicTrack(
        file: '$i.mp3',
        audioUrl: '',
        sourceWorldoId: '',
        sourceWorldoName: '',
        artist: 'Artist',
        title: 'Track $i',
        coverUrl: 'assets/mini_phone/loc_1_1_1.jpg',
        likeCount: 0,
        isLiked: false,
      ),
  ];
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  tearDown(
    () => VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    ),
  );

  testWidgets(
    'cover follows finger, then commits once and stays aligned in both directions',
    (tester) async {
      var index = 0, changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => MiniMusicCoverSwipe(
                  track: tracks[index],
                  previousTrack: tracks[(index + 2) % 3],
                  nextTrack: tracks[(index + 1) % 3],
                  width: 300,
                  height: 400,
                  enabled: true,
                  preloadNext: false,
                  onNext: () => setState(() {
                    index = (index + 1) % 3;
                    changes++;
                  }),
                  onPrevious: () => setState(() {
                    index = (index + 2) % 3;
                    changes++;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final swipe = find.byType(MiniMusicCoverSwipe);
      final left = tester.getTopLeft(swipe).dx;
      for (final direction in [-1.0, 1.0]) {
        final initialIndex = index;
        final initialChanges = changes;
        final gesture = await tester.startGesture(tester.getCenter(swipe));
        await gesture.moveBy(Offset(direction * 30, 0));
        await gesture.moveBy(Offset(direction * 90, 0));
        await tester.pump();
        final current = find.byWidgetPredicate(
          (w) =>
              w is MiniMusicCover && w.track.file == tracks[initialIndex].file,
        );
        expect(
          (tester.getTopLeft(current).dx - left) * direction,
          greaterThan(40),
        );
        expect(changes, initialChanges);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(changes, initialChanges + 1);
        expect(
          tester.getTopLeft(find.byType(MiniMusicCover)).dx,
          closeTo(left, .01),
        );
      }
      expect(index, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceled drag returns without switching; disposal during settle is safe',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: MiniMusicCoverSwipe(
              track: tracks[0],
              previousTrack: tracks[2],
              nextTrack: tracks[1],
              width: 300,
              height: 400,
              enabled: true,
              preloadNext: false,
              onNext: () => changes++,
              onPrevious: () => changes++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final swipe = find.byType(MiniMusicCoverSwipe);
      final gesture = await tester.startGesture(tester.getCenter(swipe));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-90, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(changes, 0);
      expect(
        tester.getTopLeft(find.byType(MiniMusicCover)),
        tester.getTopLeft(swipe),
      );
      await tester.drag(swipe, const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(changes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_widgets.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

MusicTrack song(String id) => MusicTrack(
  file: '$id.mp3',
  audioUrl: 'https://audio.test/$id.mp3',
  sourceWorldoId: 'o_test',
  sourceWorldoName: 'Worldo',
  artist: 'Artist',
  title: 'Song $id',
  coverUrl: 'https://covers.test/$id.jpg',
);
Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(child: child),
    ),
  ),
);

double offset(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(MiniMusicMarquee),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[12];

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    debugGenesisStaticNetworkImageCompleter = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'long metadata stays single-line and moves slowly without progress rebuild resets',
    (tester) async {
      Widget marquee({String identity = 'a', bool active = true}) => host(
        SizedBox(
          width: 100,
          child: MiniMusicMarquee(
            text: 'A very long music title with many more words than fit',
            style: const TextStyle(fontSize: 20),
            identity: identity,
            active: active,
          ),
        ),
      );
      await tester.pumpWidget(marquee());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(offset(tester), closeTo(0, .5));
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), closeTo(-20, 1));
      expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
      await tester.pumpWidget(marquee());
      expect(offset(tester), closeTo(-20, 1));
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), closeTo(-40, 1));
      final textWidth = tester.getSize(find.byType(Text)).width;
      final distance = textWidth - 100;
      await tester.pump(
        Duration(milliseconds: ((distance / 20 - 2) * 1000).round()),
      );
      expect(offset(tester), closeTo(-distance, 1));
      await tester.pump(const Duration(seconds: 2));
      expect(offset(tester), closeTo(-distance, 1));
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), closeTo(-distance + 20, 1));
      await tester.pumpWidget(marquee(active: false));
      await tester.pump();
      final paused = offset(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(offset(tester), closeTo(paused, .1));
      await tester.pumpWidget(marquee(identity: 'b'));
      await tester.pump();
      expect(offset(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('large text in a narrow area remains one line', (tester) async {
    await tester.pumpWidget(
      host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const SizedBox(
            width: 70,
            child: MiniMusicMarquee(
              text: 'A long title at a large text size',
              style: TextStyle(fontSize: 24),
              identity: 'large',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'short text and reduced-motion text never start marquee animations',
    (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 200,
            child: MiniMusicMarquee(
              text: 'Short',
              style: TextStyle(fontSize: 20),
              identity: 'a',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBox), findsNothing);
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 80,
            child: MiniMusicMarquee(
              text: 'Long title which cannot fit',
              style: TextStyle(fontSize: 20),
              identity: 'a',
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byType(Text)).overflow,
        TextOverflow.ellipsis,
      );
      expect(find.byType(OverflowBox), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'marquee pauses in background and resets only when text/geometry changes',
    (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 100,
            child: MiniMusicMarquee(
              text: 'Long title which cannot fit in one hundred pixels',
              style: TextStyle(fontSize: 20),
              identity: 'a',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final before = offset(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(offset(tester), closeTo(before, .1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final compact in [false, true]) {
    testWidgets(
      'tap and enlarged drag hit-area each submit exactly one seek (compact=$compact)',
      (tester) async {
        final seeks = <Duration>[];
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 300,
              child: MiniMusicSeekBar(
                identity: 'a',
                position: const Duration(seconds: 5),
                duration: const Duration(seconds: 90),
                buffered: const Duration(seconds: 20),
                enabled: true,
                compact: compact,
                onSeek: (position) async {
                  seeks.add(position);
                },
              ),
            ),
          ),
        );
        final slider = find.byType(Slider);
        expect(tester.getSize(slider).height, greaterThanOrEqualTo(48));
        expect(tester.widget<Slider>(slider).secondaryTrackValue, 20000);
        final rect = tester.getRect(slider);
        await tester.tapAt(
          Offset(rect.left + rect.width * .75, rect.center.dy),
        );
        await tester.pumpAndSettle();
        expect(seeks, hasLength(1));
        expect(seeks.single.inSeconds, inInclusiveRange(60, 75));
        seeks.clear();
        final gesture = await tester.startGesture(
          Offset(rect.left + rect.width * .1, rect.center.dy + 18),
        );
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();
        expect(seeks, isEmpty);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(seeks, hasLength(1));
        expect(seeks.single.inSeconds, greaterThan(20));
      },
    );
  }
  testWidgets(
    'seek preview clears on song change and unknown duration disables interaction',
    (tester) async {
      final pending = Completer<void>();
      Widget bar(String identity, Duration? duration, Duration buffer) => host(
        SizedBox(
          width: 300,
          child: MiniMusicSeekBar(
            identity: identity,
            position: const Duration(seconds: 1),
            duration: duration,
            buffered: buffer,
            enabled: true,
            onSeek: (_) => pending.future,
          ),
        ),
      );
      await tester.pumpWidget(
        bar('a', const Duration(seconds: 90), const Duration(seconds: 120)),
      );
      expect(
        tester.widget<Slider>(find.byType(Slider)).secondaryTrackValue,
        90000,
      );
      await tester.tapAt(
        tester.getRect(find.byType(Slider)).centerRight - const Offset(20, 0),
      );
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        greaterThan(60000),
      );
      await tester.pumpWidget(bar('b', null, Duration.zero));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0);
      expect(slider.secondaryTrackValue, 0);
      expect(slider.onChanged, isNull);
      pending.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'cover resize URL and decode dimensions follow global DPR and shared tiers',
    (tester) async {
      final small =
          miniMusicCoverProvider(song('a'), const Size(44, 66), 3)
              as GenesisStaticNetworkImageProvider;
      expect(
        small.imageUrl,
        'https://covers.test/a.jpg?x-oss-process=image/resize,w_90/format,webp',
      );
      expect(small.cacheWidth, 88);
      expect(small.cacheHeight, 132);
      final large =
          miniMusicCoverProvider(song('a'), const Size(200, 300), 3)
              as GenesisStaticNetworkImageProvider;
      expect(large.imageUrl, contains('resize,w_720'));
      expect(large.cacheWidth, 400);
    },
  );

  Future<ui.Image> image(
    WidgetTester tester,
  ) async => (await tester.runAsync(() async {
    final bytes = await rootBundle.load('assets/images/default_list_image.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }))!;
  bool displays(WidgetTester tester, String id) => tester
      .widgetList<Image>(find.byType(Image))
      .any(
        (image) =>
            image.image is GenesisStaticNetworkImageProvider &&
            (image.image as GenesisStaticNetworkImageProvider).imageUrl
                .contains('/$id.jpg'),
      );

  testWidgets(
    'old cover expires after 200ms even when replacement has not loaded; late images cannot flash back',
    (tester) async {
      final decoded = await image(tester);
      final gates = <String, Completer<ImageInfo>>{};
      debugGenesisStaticNetworkImageCompleter = (key) {
        final gate = gates.putIfAbsent(key.imageUrl, Completer<ImageInfo>.new);
        return OneFrameImageStreamCompleter(gate.future);
      };
      Widget cover(String id) => host(
        MiniMusicCover(track: song(id), width: 100, height: 150, radius: 16),
      );
      await tester.pumpWidget(cover('a'));
      gates.values.single.complete(ImageInfo(image: decoded.clone()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(displays(tester, 'a'), isTrue);
      await tester.pumpWidget(cover('b'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(displays(tester, 'a'), isTrue);
      expect(displays(tester, 'b'), isTrue);
      await tester.pump(const Duration(milliseconds: 110));
      expect(displays(tester, 'a'), isFalse);
      expect(displays(tester, 'b'), isTrue);
      await tester.pumpWidget(cover('c'));
      final b = gates.entries
          .singleWhere((e) => e.key.contains('/b.jpg'))
          .value;
      b.complete(ImageInfo(image: decoded.clone()));
      await tester.pump(const Duration(milliseconds: 210));
      expect(displays(tester, 'a'), isFalse);
      expect(displays(tester, 'b'), isFalse);
      gates.entries
          .singleWhere((e) => e.key.contains('/c.jpg'))
          .value
          .complete(ImageInfo(image: decoded.clone()));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      decoded.dispose();
    },
  );
  testWidgets(
    'hidden covers defer next-image prefetch until they become visible',
    (tester) async {
      final decoded = await image(tester);
      final calls = <GenesisStaticNetworkImageProvider>[];
      debugGenesisStaticNetworkImageCompleter = (key) {
        calls.add(key);
        return OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: decoded.clone())),
        );
      };
      Widget cover(bool hidden) => host(
        Offstage(
          offstage: hidden,
          child: MiniMusicCover(
            track: song('a'),
            nextTrack: song('b'),
            preloadNext: true,
            width: 100,
            height: 150,
            radius: 16,
          ),
        ),
      );
      await tester.pumpWidget(cover(true));
      await tester.pumpAndSettle();
      expect(calls.where((key) => key.imageUrl.contains('/b.jpg')), isEmpty);
      await tester.pumpWidget(cover(false));
      await tester.pumpAndSettle();
      expect(
        calls.where((key) => key.imageUrl.contains('/b.jpg')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      decoded.dispose();
    },
  );
  testWidgets(
    'next cover prefetch and display share the same in-flight/decoded image key',
    (tester) async {
      final decoded = await image(tester);
      final calls = <GenesisStaticNetworkImageProvider>[];
      debugGenesisStaticNetworkImageCompleter = (key) {
        calls.add(key);
        return OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: decoded.clone())),
        );
      };
      await tester.pumpWidget(
        host(
          MiniMusicCover(
            track: song('a'),
            nextTrack: song('b'),
            preloadNext: true,
            width: 100,
            height: 150,
            radius: 16,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        calls.where((key) => key.imageUrl.contains('/b.jpg')),
        hasLength(1),
      );
      await tester.pumpWidget(
        host(
          MiniMusicCover(track: song('b'), width: 100, height: 150, radius: 16),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((key) => key.imageUrl.contains('/b.jpg')),
        hasLength(1),
      );
      expect(displays(tester, 'a'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      decoded.dispose();
    },
  );
  testWidgets(
    'failed cover remains placeholder and reduced motion switches immediately',
    (tester) async {
      debugGenesisStaticNetworkImageCompleter = (_) =>
          OneFrameImageStreamCompleter(Future.error(StateError('offline')));
      await tester.pumpWidget(
        host(
          MiniMusicCover(track: song('a'), width: 100, height: 150, radius: 16),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ColoredBox), findsWidgets);
      await tester.pumpWidget(
        host(
          MiniMusicCover(track: song('b'), width: 100, height: 150, radius: 16),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(displays(tester, 'a'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

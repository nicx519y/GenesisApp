import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

const defaults = LocationChatBubbleLayoutSettings.defaults;
const bodyKey = ValueKey('body');

Widget harness(
  String text, {
  LocationChatBubbleLayoutSettings settings = defaults,
  bool streaming = true,
  Object identity = 'message',
  Object? continuation,
  Widget? content,
  TextDirection direction = TextDirection.ltr,
  bool scoped = true,
  bool animateArrival = false,
  bool mountedBody = true,
}) {
  final body = ChatStreamingMessage(
    key: ValueKey(identity),
    identity: identity,
    continuationIdentity: continuation,
    streaming: streaming,
    animateArrival: animateArrival,
    child: ChatBubbleSurface(
      color: Colors.black,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      child:
          content ??
          ChatStreamingText(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
    ),
  );
  return MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            child: RepaintBoundary(
              key: bodyKey,
              child: scoped
                  ? ChatStreamingEffects(
                      settings: settings,
                      child: mountedBody ? body : const SizedBox.shrink(),
                    )
                  : body,
            ),
          ),
        ),
      ),
    ),
  );
}

double height(WidgetTester tester) =>
    tester.getSize(find.byKey(bodyKey)).height;

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 20));
  expect(tester.takeException(), isNull);
}

void main() {
  double progress(WidgetTester tester) => ChatStreamingBody.revealedGraphemesOf(
    tester.element(find.byType(ChatStreamingBody).first),
  );

  Widget queued({
    List<int> mounted = const [0, 1, 2],
    bool firstStreaming = false,
    bool enabled = true,
    bool freezeFirst = false,
    String firstText = 'abcd',
    Object operation = 0,
  }) => MaterialApp(
    home: Scaffold(
      body: ChatStreamingEffects(
        operationIdentity: operation,
        presentationRevision: (
          firstText,
          firstStreaming,
          freezeFirst,
          Object.hashAll(mounted),
        ),
        settings: defaults.copyWith(
          animateStreamingHeight: false,
          streamingTextReveal: enabled,
        ),
        child: Column(
          children: [
            for (final index in mounted)
              TickerMode(
                key: ValueKey(index),
                enabled: index != 0 || !freezeFirst,
                child: ChatStreamingMessage(
                  identity: index,
                  order: () => index.toDouble(),
                  streaming: index == 0 && firstStreaming,
                  animateArrival: true,
                  child: Semantics(
                    label: 'message-row-$index',
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('sender-$index'),
                          ChatBubbleSurface(
                            color: Colors.black,
                            borderRadius: BorderRadius.zero,
                            padding: const EdgeInsets.all(12),
                            child: ChatStreamingText(
                              child: Text(index == 0 ? firstText : 'abcd'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Builder(
              builder: (context) => Text(
                ChatStreamingEffects.isSettledOf(context)
                    ? 'settled'
                    : 'revealing',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  double queuedProgress(WidgetTester tester, int index) =>
      ChatStreamingBody.revealedGraphemesOf(
        tester.element(
          find.descendant(
            of: find.byKey(ValueKey(index)),
            matching: find.byType(ChatStreamingBody),
          ),
        ),
      );

  testWidgets(
    'bubbles reveal serially in display order with no waiting credit',
    (tester) async {
      // Deliberately mount out of sequence to exercise explicit display order.
      await tester.pumpWidget(queued(mounted: [2, 0, 1]));
      await tester.pump(const Duration(milliseconds: 12));
      expect(find.text('settled'), findsNothing);
      expect(queuedProgress(tester, 0), closeTo(2, .001));
      expect(queuedProgress(tester, 1), 0);
      expect(queuedProgress(tester, 2), 0);
      await tester.pump(const Duration(milliseconds: 36));
      expect(queuedProgress(tester, 0), 4);
      expect(queuedProgress(tester, 1), 0);
      await tester.pump(); // Start the next ticker, without accumulated credit.
      await tester.pump(const Duration(milliseconds: 12));
      expect(queuedProgress(tester, 1), closeTo(2, .001));
      expect(queuedProgress(tester, 2), 0);
      await settle(tester);
      expect(find.text('settled'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(queuedProgress(tester, i), 4);
      }
    },
  );

  testWidgets('queued rows hide chrome, spacing, geometry and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(queued());
    for (var index = 0; index < 3; index++) {
      final row = find.byKey(ValueKey(index));
      expect(tester.getSize(row).height, 0);
      expect(
        (tester.renderObject(row) as RenderBox).hitTest(
          BoxHitTestResult(),
          position: const Offset(1, 1),
        ),
        isFalse,
      );
      expect(
        ChatBubbleGeometry.globalBoundsOf(tester.renderObject(row)),
        isNull,
      );
      expect(find.bySemanticsLabel(RegExp('message-row-$index')), findsNothing);
    }
    await tester.pump(const Duration(milliseconds: 6));
    expect(
      tester.getSize(find.byKey(const ValueKey(0))).height,
      greaterThan(0),
    );
    expect(tester.getSize(find.byKey(const ValueKey(1))).height, 0);
    expect(find.bySemanticsLabel(RegExp('message-row-0')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('message-row-1')), findsNothing);
    await settle(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey(2))).height,
      greaterThan(0),
    );
    semantics.dispose();
  });

  testWidgets('new operation retires old reveal tasks before new replies', (
    tester,
  ) async {
    await tester.pumpWidget(queued(firstStreaming: true));
    await tester.pump(const Duration(milliseconds: 6));
    expect(queuedProgress(tester, 0), 1);
    await tester.pumpWidget(queued(mounted: [0, 1, 2, 3], operation: 1));
    for (var index = 0; index < 3; index++) {
      expect(queuedProgress(tester, index), 4);
    }
    expect(queuedProgress(tester, 3), 0);
    await tester.pump(const Duration(milliseconds: 6));
    expect(queuedProgress(tester, 3), 1);
    await settle(tester);
  });

  testWidgets('chunk gaps retain the turn until the first stream finishes', (
    tester,
  ) async {
    await tester.pumpWidget(queued(firstStreaming: true));
    await settle(tester);
    expect(find.text('settled'), findsNothing);
    expect(queuedProgress(tester, 1), 0);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(
      queued(firstStreaming: true, firstText: 'abcdefgh'),
    );
    await tester.pump(const Duration(milliseconds: 6));
    expect(queuedProgress(tester, 0), closeTo(5, .001));
    expect(queuedProgress(tester, 1), 0);
    await tester.pumpWidget(queued(firstText: 'abcdefgh'));
    await settle(tester);
    expect(queuedProgress(tester, 0), 8);
    expect(queuedProgress(tester, 2), 4);
  });

  for (final freeze in [false, true]) {
    testWidgets(
      'removing or freezing the active bubble releases its turn ($freeze)',
      (tester) async {
        await tester.pumpWidget(queued(firstStreaming: true));
        await tester.pump(const Duration(milliseconds: 6));
        await tester.pumpWidget(
          queued(
            firstStreaming: true,
            mounted: freeze ? [0, 1, 2] : [1, 2],
            freezeFirst: freeze,
          ),
        );
        await tester.pump(const Duration(milliseconds: 6));
        expect(queuedProgress(tester, 1), closeTo(1, .001));
        expect(queuedProgress(tester, 2), 0);
        await settle(tester);
        expect(queuedProgress(tester, 2), 4);
      },
    );
  }

  testWidgets('disabling reveal immediately displays the whole queue', (
    tester,
  ) async {
    await tester.pumpWidget(queued(firstStreaming: true));
    await tester.pump(const Duration(milliseconds: 6));
    await tester.pumpWidget(queued(firstStreaming: true, enabled: false));
    for (var i = 0; i < 3; i++) {
      expect(queuedProgress(tester, i), 4);
    }
    await tester.pumpWidget(queued(firstStreaming: true));
    await settle(tester);
    expect(queuedProgress(tester, 2), 4);
  });

  testWidgets('background pause is not presentation completion', (
    tester,
  ) async {
    await tester.pumpWidget(queued());
    await tester.pump(const Duration(milliseconds: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('settled'), findsNothing);
    expect(queuedProgress(tester, 1), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await settle(tester);
    expect(find.text('settled'), findsOneWidget);
  });

  testWidgets('chunk size and terminal frames never exceed the grapheme rate', (
    tester,
  ) async {
    final settings = defaults.copyWith(animateStreamingHeight: false);
    await tester.pumpWidget(harness('a' * 200, settings: settings));
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(tester), closeTo(10, 0.001));
    for (var chunk = 0; chunk < 12; chunk++) {
      final before = progress(tester);
      await tester.pumpWidget(
        harness('a' * (300 + chunk * 100), settings: settings),
      );
      expect(progress(tester), closeTo(before, 0.001));
      await tester.pump(const Duration(milliseconds: 6));
      expect(progress(tester), closeTo(before + 1, 0.001));
    }
    final beforeEnd = progress(tester);
    await tester.pumpWidget(
      harness('a' * 1500, settings: settings, streaming: false),
    );
    expect(progress(tester), closeTo(beforeEnd, 0.001));
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(tester), closeTo(beforeEnd + 10, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'one terminal arrival still reveals and counts complete graphemes',
    (tester) async {
      await tester.pumpWidget(
        harness('中👨‍👩‍👧‍👦e\u0301文', streaming: false, animateArrival: true),
      );
      expect(progress(tester), 0);
      await tester.pump(const Duration(milliseconds: 12));
      expect(progress(tester), closeTo(2, 0.001));
      await settle(tester);
      expect(progress(tester), 4);
    },
  );

  testWidgets('remount and canonical identity preserve unfinished progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness('a' * 60, identity: 'temporary', continuation: 'round/sender'),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final before = progress(tester);
    await tester.pumpWidget(harness('', mountedBody: false));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(
      harness('a' * 60, identity: 'temporary', continuation: 'round/sender'),
    );
    expect(progress(tester), closeTo(before, 0.001));
    await tester.pumpWidget(
      harness(
        'a' * 70,
        identity: 'canonical',
        continuation: 'round/sender',
        streaming: false,
      ),
    );
    expect(progress(tester), closeTo(before, 0.001));
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(tester), closeTo(before + 10, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('background time and idle time cannot buy reveal credit', (
    tester,
  ) async {
    await tester.pumpWidget(harness('a' * 60));
    await tester.pump(const Duration(milliseconds: 60));
    final before = progress(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(progress(tester), closeTo(before, 0.001));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(tester), closeTo(before + 10, 0.001));
    await tester.pumpWidget(harness('a'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(harness('a' * 100));
    expect(progress(tester), 1);
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(tester), closeTo(11, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('height grows and shrinks through intermediate sizes', (
    tester,
  ) async {
    final settings = defaults.copyWith(streamingTextReveal: false);
    await tester.pumpWidget(harness('one', settings: settings));
    final one = height(tester);
    await tester.pumpWidget(harness('one\ntwo\nthree', settings: settings));
    expect(height(tester), one);
    await tester.pump(const Duration(milliseconds: 90));
    expect(height(tester), greaterThan(one));
    final middle = height(tester);
    await settle(tester);
    final three = height(tester);
    expect(three, greaterThan(middle));
    await tester.pumpWidget(
      harness('one', settings: settings, streaming: false),
    );
    expect(height(tester), three);
    await tester.pump(const Duration(milliseconds: 90));
    expect(height(tester), inExclusiveRange(one, three));
    await settle(tester);
    expect(height(tester), one);
  });

  testWidgets('a multi-line chunk occupies only revealed lines', (
    tester,
  ) async {
    final settings = defaults.copyWith(
      animateStreamingHeight: false,
      streamingTextDurationMs: 1000,
    );
    await tester.pumpWidget(harness('aaaa\nbbbb\ncccc', settings: settings));
    expect(height(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    final first = height(tester);
    expect(first, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 5000));
    expect(height(tester), greaterThan(first));
    await settle(tester);
    expect(height(tester), closeTo(first * 3, 1));
  });

  testWidgets('successive chunks keep moving forward and final text settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        'first line',
        settings: defaults.copyWith(streamingTextDurationMs: 300),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final before = height(tester);
    await tester.pumpWidget(
      harness(
        'first line\nsecond line',
        settings: defaults.copyWith(streamingTextDurationMs: 300),
      ),
    );
    expect(height(tester), greaterThanOrEqualTo(before));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(
      harness('first line\nsecond line\nlast', streaming: false),
    );
    await settle(tester);
    final animated = height(tester);
    await tester.pumpWidget(
      harness('first line\nsecond line\nlast', scoped: false),
    );
    expect(height(tester), animated);
  });

  testWidgets('switches snap immediately and reenabling does not replay', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        'one\ntwo\nthree',
        settings: defaults.copyWith(streamingTextDurationMs: 1000),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      harness(
        'one\ntwo\nthree',
        settings: defaults.copyWith(
          streamingTextReveal: false,
          animateStreamingHeight: false,
        ),
      ),
    );
    final full = height(tester);
    await tester.pumpWidget(harness('one\ntwo\nthree'));
    expect(height(tester), full);
    await settle(tester);
    expect(height(tester), full);
  });

  testWidgets('duration changes apply to the next target without restarting', (
    tester,
  ) async {
    final slow = defaults.copyWith(
      streamingTextReveal: false,
      streamingHeightDurationMs: 1000,
    );
    await tester.pumpWidget(harness('one', settings: slow));
    await tester.pumpWidget(harness('one\ntwo\nthree', settings: slow));
    await tester.pump(const Duration(milliseconds: 200));
    final before = height(tester);
    await tester.pumpWidget(
      harness(
        'one\ntwo\nthree',
        settings: slow.copyWith(streamingHeightDurationMs: 40),
      ),
    );
    expect(height(tester), before);
    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = height(tester);
    await settle(tester);
    expect(height(tester), greaterThan(intermediate));
  });

  testWidgets('history and unscoped consumers display immediately', (
    tester,
  ) async {
    await tester.pumpWidget(harness('history\nsecond', streaming: false));
    final full = height(tester);
    expect(full, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(height(tester), full);
    await tester.pumpWidget(harness('history\nsecond', scoped: false));
    expect(height(tester), full);
  });

  testWidgets(
    'ordered rich paragraphs reveal sequentially, including placeholders',
    (tester) async {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChatStreamingText(
            child: Text(
              'first paragraph',
              style: TextStyle(fontSize: 20, height: 1),
            ),
          ),
          const SizedBox(height: 12),
          ChatStreamingText(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'second '),
                  WidgetSpan(
                    child: RepaintBoundary(
                      child: Container(
                        width: 24,
                        height: 20,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const TextSpan(text: ' 👨‍👩‍👧‍👦 e\u0301'),
                ],
              ),
              style: const TextStyle(fontSize: 20, height: 1),
            ),
          ),
        ],
      );
      final settings = defaults.copyWith(
        animateStreamingHeight: false,
        streamingTextDurationMs: 1000,
      );
      await tester.pumpWidget(
        harness('', content: content, settings: settings),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final first = height(tester);
      await tester.pump(const Duration(milliseconds: 8000));
      expect(height(tester), greaterThan(first));
      expect(tester.takeException(), isNull);
      await settle(tester);
    },
  );

  testWidgets('mask paints partially transparent pixels and settles opaque', (
    tester,
  ) async {
    final settings = defaults.copyWith(
      animateStreamingHeight: false,
      streamingTextDurationMs: 1000,
    );
    await tester.pumpWidget(harness('AAAAAAAAAAAA', settings: settings));
    await tester.pump(const Duration(milliseconds: 500));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(bodyKey),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!.buffer.asUint8List();
    image.dispose();
    // Ahem has hard glyph edges; intermediate gray pixels come from feathering.
    expect(
      [
        for (var i = 0; i < bytes.length; i += 4) bytes[i],
      ].any((v) => v > 5 && v < 250),
      isTrue,
    );
    await settle(tester);
  });

  testWidgets(
    'RTL and grapheme corrections do not throw or truncate final text',
    (tester) async {
      await tester.pumpWidget(
        harness('مرحبا 👨‍👩‍👧‍👦 e\u0301\n你好', direction: TextDirection.rtl),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(
        harness(
          'مرحبا 👨‍👩‍👧‍👦',
          direction: TextDirection.rtl,
          streaming: false,
        ),
      );
      await settle(tester);
      expect(find.text('مرحبا 👨‍👩‍👧‍👦'), findsOneWidget);
    },
  );

  testWidgets('final server identity inherits the stream size for shrinking', (
    tester,
  ) async {
    final settings = defaults.copyWith(streamingTextReveal: false);
    await tester.pumpWidget(
      harness(
        'one\ntwo\nthree',
        continuation: 'round-sender',
        settings: settings,
      ),
    );
    final before = height(tester);
    await tester.pumpWidget(
      harness(
        'one',
        identity: 'server-id',
        continuation: 'round-sender',
        streaming: false,
        settings: settings,
      ),
    );
    expect(height(tester), before);
    await tester.pump(const Duration(milliseconds: 90));
    expect(height(tester), lessThan(before));
    await settle(tester);
  });
  for (final kind in [
    'user',
    'character',
    'narrator',
    'system',
    'tick',
    'story_events',
    'characters_moved',
    'user_enter_location',
  ]) {
    testWidgets('$kind routes streaming prose through the common animation', (
      tester,
    ) async {
      const prose =
          'First paragraph with *emphasis* 👨‍👩‍👧‍👦.\nSecond paragraph follows.';
      const story = ChatStoryEventsPayloadVm(
        locationId: 'l',
        locationName: 'Room',
        paragraphs: [
          ChatStoryEventParagraphVm(
            timestamp: '12:00',
            text: prose,
            clue: 'A clue',
            visibilityLabel: 'public',
          ),
        ],
      );
      const movement = ChatCharactersMovedPayloadVm(
        movements: [
          ChatCharacterMovementVm(
            characterId: 'c',
            characterName: 'A traveler',
            toLocationId: 'l',
            toLocationName: 'A distant room',
          ),
        ],
      );
      final ChatTimelinePayloadVm? payload = switch (kind) {
        'tick' => const ChatTickPayloadVm(
          globalText: prose,
          storyEvents: story,
          charactersMoved: movement,
        ),
        'story_events' => story,
        'characters_moved' => movement,
        'user_enter_location' => const ChatUserEnterLocationPayloadVm(
          characterId: 'c',
          toLocationId: 'l',
          text: 'A traveler came to a distant room',
        ),
        _ => null,
      };
      Widget view(bool streaming, {bool enabled = true}) => MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: ChatStreamingEffects(
                  settings: defaults.copyWith(streamingTextDurationMs: 600),
                  child: RepaintBoundary(
                    key: bodyKey,
                    child: ChatStreamingMessage(
                      identity: kind,
                      streaming: streaming && enabled,
                      child: ChatMessageRow(
                        message: ChatMessageVm(
                          localId: kind,
                          senderId: 'c',
                          senderName: 'Traveler',
                          isMe: kind == 'user',
                          text: prose,
                          senderType: kind,
                          status: streaming ? 'streaming' : 'sent',
                          timelinePayload: payload,
                        ),
                        showDateDivider: false,
                        style: kLocationChatStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(true));
      final first = height(tester);
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.takeException(), isNull);
      await settle(tester);
      final full = height(tester);
      final bodyHeight = tester
          .getSize(find.byType(ChatStreamingBody).first)
          .height;
      expect(full, greaterThan(first));
      await tester.pumpWidget(view(false));
      await settle(tester);
      expect(
        tester.getSize(find.byType(ChatStreamingBody).first).height,
        bodyHeight,
      );
    });
  }

  testWidgets('text duration changes do not restart an active sweep', (
    tester,
  ) async {
    final slow = defaults.copyWith(
      animateStreamingHeight: false,
      streamingTextDurationMs: 1000,
    );
    await tester.pumpWidget(harness('aaaa\nbbbb\ncccc', settings: slow));
    await tester.pump(const Duration(milliseconds: 200));
    final before = height(tester);
    await tester.pumpWidget(
      harness(
        'aaaa\nbbbb\ncccc',
        settings: slow.copyWith(streamingTextDurationMs: 40),
      ),
    );
    expect(height(tester), before);
    await tester.pump(const Duration(milliseconds: 100));
    expect(height(tester), greaterThan(before));
    await settle(tester);
    expect(height(tester), greaterThan(before));
  });

  for (final readingHistory in [false, true]) {
    testWidgets(
      'streaming layout preserves scroll intent (reading history: $readingHistory)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        Widget view(String text, {bool complete = false}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: ChatStreamingEffects(
                settings: defaults,
                child: NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    topTitle: '',
                    showDateDividers: false,
                    style: kLocationChatStyle,
                    messages: [
                      for (var i = 0; i < 20; i++)
                        ChatMessageVm(
                          localId: 'message-$i',
                          senderId: 'peer',
                          senderName: 'Peer',
                          text: i == 19 ? text : 'Message $i',
                          isMe: false,
                          status: i == 19 && !complete ? 'streaming' : 'sent',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(view('First'));
        await settle(tester);
        coordinator.requestBottom(
          reason: LocationChatBottomReason.unseenMessageNotice,
          behavior: LocationChatBottomBehavior.jump,
        );
        await settle(tester);
        if (readingHistory) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 180),
          );
          await settle(tester);
          expect(coordinator.isReadingHistory, isTrue);
        }
        final before = coordinator.controller.position.pixels;
        await tester.pumpWidget(view('First\nMore content' * 6));
        await tester.pump(const Duration(milliseconds: 60));
        await settle(tester);
        if (readingHistory) {
          expect(coordinator.controller.position.pixels, closeTo(before, .1));
        } else {
          expect(coordinator.controller.position.pixels, greaterThan(before));
          expect(coordinator.isAtBottom, isTrue);
        }
        final grown = coordinator.controller.position.pixels;
        await tester.pumpWidget(view('First', complete: true));
        await settle(tester);
        expect(coordinator.controller.position.pixels, closeTo(grown, .1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('scaled mentions and iOS emphasis retain their settled layout', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      characters: const [
        ChatMentionEntry(
          id: 'alice',
          name: 'Alice',
          type: ChatMentionType.character,
        ),
      ],
    );
    Widget view(bool enabled) => MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ChatMentionScope(
              catalog: catalog,
              child: ChatStreamingEffects(
                settings: defaults.copyWith(
                  animateStreamingHeight: enabled,
                  streamingTextReveal: enabled,
                ),
                child: ChatStreamingMessage(
                  identity: 'mention',
                  streaming: true,
                  child: ChatMessageBubble(
                    message: ChatMessageVm(
                      localId: 'mention',
                      senderId: 'peer',
                      senderName: 'Peer',
                      text:
                          '@Alice<alice> *gentle emphasis* 👨‍👩‍👧‍👦 e\u0301',
                      isMe: false,
                      status: 'streaming',
                    ),
                    style: kLocationChatStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
    await settle(tester);
    final animated = tester.getSize(find.byType(ChatStreamingBody));
    await tester.pumpWidget(view(false));
    expect(tester.getSize(find.byType(ChatStreamingBody)), animated);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing an active message disposes its ticker and isolates progress',
    (tester) async {
      await tester.pumpWidget(harness('old stream with multiple words'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(harness('new stream', identity: 'new-message'));
      await settle(tester);
      expect(find.text('old stream with multiple words'), findsNothing);
      expect(find.text('new stream'), findsOneWidget);
      await tester.pumpWidget(
        harness('next unfinished stream', identity: 'third'),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

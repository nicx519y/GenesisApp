import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

Widget _composer(
  TextEditingController controller, {
  ValueChanged<double>? onHeightChanged,
}) => Material(
  child: Align(
    alignment: Alignment.bottomCenter,
    child: ChatComposer(
      controller: controller,
      inputEnabled: true,
      sendEnabled: false,
      sending: false,
      onSend: () async {},
      onHeightChanged: onHeightChanged,
    ),
  ),
);

class _LayoutTwice extends SingleChildRenderObjectWidget {
  const _LayoutTwice({required super.child});

  @override
  _RenderLayoutTwice createRenderObject(BuildContext context) =>
      _RenderLayoutTwice();
}

class _RenderLayoutTwice extends RenderProxyBox {
  double? firstHeight;

  @override
  void performLayout() {
    child!.layout(
      const BoxConstraints.tightFor(width: 120),
      parentUsesSize: true,
    );
    firstHeight = child!.size.height;
    child!.layout(
      const BoxConstraints.tightFor(width: 320),
      parentUsesSize: true,
    );
    size = constraints.constrain(child!.size);
  }
}

void main() {
  testWidgets('multiple layouts report only the final height of the frame', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: List.filled(6, 'word').join(' '),
    );
    final heights = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: _LayoutTwice(
              child: ChatComposer(
                controller: controller,
                inputEnabled: true,
                sendEnabled: false,
                sending: false,
                onSend: () async {},
                onHeightChanged: heights.add,
              ),
            ),
          ),
        ),
      ),
    );
    final finalHeight = tester.getSize(find.byType(ChatComposer)).height;
    final layout = tester.renderObject<_RenderLayoutTwice>(
      find.byType(_LayoutTwice),
    );
    expect(layout.firstHeight, greaterThan(finalHeight));
    expect(heights, [finalHeight]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final listening in [false, true]) {
    testWidgets(
      'retained composer waits for first visible layout (listener: $listening)',
      (tester) async {
        final controller = TextEditingController();
        final heights = <double>[];
        final retained = OverlayEntry(
          maintainState: true,
          builder: (_) => _composer(
            controller,
            onHeightChanged: listening ? heights.add : null,
          ),
        );
        final cover = OverlayEntry(
          opaque: true,
          builder: (_) => const ColoredBox(color: Colors.black),
        );
        await tester.pumpWidget(
          MaterialApp(home: Overlay(initialEntries: [retained, cover])),
        );
        expect(tester.takeException(), isNull);
        expect(heights, isEmpty);
        await tester.pumpAndSettle();
        expect(heights, isEmpty);

        cover.remove();
        await tester.pump();
        expect(tester.takeException(), isNull);
        final firstHeight = tester.getSize(find.byType(ChatComposer)).height;
        expect(heights, listening ? [firstHeight] : isEmpty);

        await tester.enterText(find.byType(TextField), 'one\ntwo\nthree');
        await tester.pump();
        final expandedHeight = tester.getSize(find.byType(ChatComposer)).height;
        expect(expandedHeight, greaterThan(firstHeight));
        expect(heights, listening ? [firstHeight, expandedHeight] : isEmpty);
        expect(tester.takeException(), isNull);

        retained.remove();
        await tester.pumpWidget(const SizedBox.shrink());
        retained.dispose();
        cover.dispose();
        controller.dispose();
      },
    );
  }

  testWidgets('height is reported once at frame end and follows text shrink', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'one\ntwo\nthree');
    final heights = <double>[];
    final phases = <SchedulerPhase>[];
    void report(double height) {
      heights.add(height);
      phases.add(SchedulerBinding.instance.schedulerPhase);
    }

    Widget build() =>
        MaterialApp(home: _composer(controller, onHeightChanged: report));
    await tester.pumpWidget(build());
    final firstHeight = tester.getSize(find.byType(ChatComposer)).height;
    expect(heights, [firstHeight]);
    expect(phases, [SchedulerPhase.postFrameCallbacks]);

    await tester.pumpWidget(build());
    await tester.pump();
    expect(heights, [firstHeight]);

    await tester.enterText(find.byType(TextField), 'one');
    await tester.pump();
    final smallerHeight = tester.getSize(find.byType(ChatComposer)).height;
    expect(smallerHeight, lessThan(firstHeight));
    expect(heights, [firstHeight, smallerHeight]);
    expect(phases, everyElement(SchedulerPhase.postFrameCallbacks));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'new height listener receives existing layout and can be removed',
    (tester) async {
      final controller = TextEditingController();
      final first = <double>[];
      final second = <double>[];
      Widget build(ValueChanged<double>? report) =>
          MaterialApp(home: _composer(controller, onHeightChanged: report));
      await tester.pumpWidget(build(null));
      final initialHeight = tester.getSize(find.byType(ChatComposer)).height;
      await tester.pumpWidget(build(first.add));
      expect(first, [initialHeight]);
      await tester.pumpWidget(build(second.add));
      expect(second, [initialHeight]);

      await tester.pumpWidget(build(null));
      await tester.enterText(find.byType(TextField), 'one\ntwo\nthree');
      await tester.pump();
      expect(first, [initialHeight]);
      expect(second, [initialHeight]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

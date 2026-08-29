import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_gradient_painter.dart';

void main() {
  testWidgets('paints the original two-stop gradient over the cover footer', (
    tester,
  ) async {
    const painter = OriginItemCoverGradientPainter(transitionHeight: 6);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 12, 18),
      Paint()..color = const Color(0xFFFF0000),
    );
    painter.paint(canvas, const Size(12, 18));
    final picture = recorder.endRecording();
    ui.Image? renderedImage;
    await tester.runAsync(() async {
      renderedImage = await picture.toImage(12, 18);
    });
    picture.dispose();
    final image = renderedImage!;
    addTearDown(image.dispose);

    ByteData? pixels;
    await tester.runAsync(() async {
      pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final data = pixels!;
    expect(_channel(data, x: 6, y: 2, width: 12, channel: 0), greaterThan(230));
    expect(_channel(data, x: 6, y: 2, width: 12, channel: 1), lessThan(20));
    expect(
      _channel(data, x: 6, y: 17, width: 12, channel: 0),
      inInclusiveRange(17, 50),
    );
    expect(_channel(data, x: 6, y: 17, width: 12, channel: 1), closeTo(17, 2));
    expect(_channel(data, x: 6, y: 17, width: 12, channel: 2), closeTo(17, 2));
    expect(
      painter.shouldRepaint(
        const OriginItemCoverGradientPainter(transitionHeight: 6),
      ),
      isFalse,
    );
  });
}

int _channel(
  ByteData data, {
  required int x,
  required int y,
  required int width,
  required int channel,
}) {
  return data.getUint8((y * width + x) * 4 + channel);
}

import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A7ae1ab84172f4ad02406/hook.dart'
    as hook;

void main() {
  test('rejects undeclared input before resource access', () async {
    await expectLater(
      hook.invoke({'operation': 'prepare'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'wait', 'foreign': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'wait'}, false, false),
      throwsArgumentError,
    );
  });
  test(
    'missing selection cannot manufacture a successful observation',
    () async {
      await expectLater(
        hook.invoke({'operation': 'wait'}, false, true),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'requires decoded images and rejects incomplete canvas draw items',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 2, 2),
        ui.Paint()..color = const ui.Color(0xff112233),
      );
      final picture = recorder.endRecording();
      ui.Image? image;
      try {
        image = await tester.runAsync(() => picture.toImage(2, 2));
        expect(image, isNotNull);
        expect(hook.canvasImagesReady([Draw(image)]), isTrue);
        expect(hook.canvasImagesReady([]), isFalse);
        expect(hook.canvasImagesReady([Child(true)]), isTrue);
        expect(hook.canvasImagesReady([Child(true), Child(true)]), isTrue);
        expect(hook.canvasImagesReady([Child(false)]), isFalse);
        expect(hook.canvasImagesReady([Child(true), Child(false)]), isFalse);
        expect(hook.canvasImagesReady([Child(true), Draw(null)]), isFalse);
        expect(hook.canvasImagesReady([Draw(null)]), isFalse);
        expect(hook.canvasImagesReady([Draw(image), Draw(null)]), isFalse);
        expect(hook.canvasImagesReady([Draw(image), Child(false)]), isFalse);
        expect(hook.canvasImagesReady([Draw(image), Child(true)]), isTrue);
      } finally {
        image?.dispose();
        picture.dispose();
      }
    },
  );
}

class Draw {
  Draw(this.image);
  final ui.Image? image;
}

class Child {
  Child(this.hasImage);
  final bool hasImage;
}

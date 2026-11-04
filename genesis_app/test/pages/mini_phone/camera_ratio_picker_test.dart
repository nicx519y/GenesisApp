import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_ratio_picker.dart';

void main() {
  testWidgets('ratio emphasis follows the finger before selection commits', (
    tester,
  ) async {
    var selected = CameraPhotoRatio.portrait;
    final changes = <CameraPhotoRatio>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => CameraRatioPicker(
                value: selected,
                onChanged: (value) {
                  changes.add(value);
                  setState(() => selected = value);
                },
              ),
            ),
          ),
        ),
      ),
    );
    Color color(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    final original = color('2:3');
    final next = color('9:16');
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('camera-ratio-picker'))),
    );
    await drag.moveBy(const Offset(-25, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await drag.moveBy(const Offset(-15, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(color('2:3'), isNot(original));
    expect(color('9:16'), isNot(next));
    expect(selected, CameraPhotoRatio.portrait);
    expect(changes, isEmpty);
    await drag.moveBy(const Offset(-25, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, CameraPhotoRatio.tall);
    expect(changes, [CameraPhotoRatio.tall]);
    expect(color('9:16'), original);
    expect(tester.takeException(), isNull);
  });
}

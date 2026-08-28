import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_exit_location_button.dart';

void main() {
  testWidgets('uses the feature map exit treatment without moving the label', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              child: WorldMapExitLocationButton(
                label: 'Upper map',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    final inkWell = find.byType(InkWell);
    final material = tester.widget<Material>(find.byType(Material).last);
    final shape = material.shape! as RoundedRectangleBorder;
    final icon = tester.widget<Icon>(
      find.byIcon(Icons.subdirectory_arrow_left),
    );
    final label = tester.widget<Text>(find.text('Upper map'));

    expect(tester.getSize(inkWell), const Size(34, 34));
    expect(material.color, const Color(0x99151517));
    expect(shape.borderRadius, BorderRadius.circular(11));
    expect(shape.side.color, const Color(0x29FFFFFF));
    expect(shape.side.width, 0.5);
    expect(icon.size, 13);
    expect(icon.color, Colors.white);
    expect(label.style?.fontSize, 12);
    expect(label.style?.height, 1);
    expect(label.style?.fontWeight, FontWeight.w600);
    expect(label.style?.color, const Color(0xFFF4F3F6));
    expect(label.style?.shadows, const <Shadow>[
      Shadow(color: Color(0xD9000000), offset: Offset(0, 1), blurRadius: 5),
    ]);
    expect(
      tester.getTopLeft(find.text('Upper map')).dx -
          tester.getTopRight(inkWell).dx,
      closeTo(9, 0.001),
    );
    expect(
      find.descendant(of: inkWell, matching: find.text('Upper map')),
      findsNothing,
    );

    await tester.tap(inkWell);
    expect(tapped, isTrue);
  });
}

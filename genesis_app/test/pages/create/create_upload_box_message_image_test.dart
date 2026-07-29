import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  testWidgets('Opening upload preview uses message image sizing', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: 'https://images.example.com/opening_100x300.webp',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CreateUploadBox(
              key: const ValueKey('opening-message-image-upload'),
              controller: controller,
              label: 'UPLOAD IMAGE',
              width: 300,
              height: 300,
              preserveImageAspectRatio: true,
              useMessageImageSizing: true,
              showRemoveLinkWhenFilled: false,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('opening-message-image-upload')),
      ),
      const Size(100, 300),
    );
    final image = tester.widget<GenesisStaticNetworkImage>(
      find.byType(GenesisStaticNetworkImage),
    );
    expect(image.imageUrl, controller.text);
    expect(image.fit, BoxFit.contain);
  });
}

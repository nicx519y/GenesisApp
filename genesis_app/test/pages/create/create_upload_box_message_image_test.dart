import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('original upload reads large image dimensions from encoded header', () {
    final pngHeader = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x1f,
      0x40,
      0x00,
      0x00,
      0x17,
      0x70,
      0x08,
      0x02,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);

    expect(
      createUploadImageSizeFromEncodedBytes(pngHeader),
      const Size(8000, 6000),
    );
  });

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

  testWidgets('original image preview bounds memory decode to display pixels', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 2.5;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final previewBytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 2, height: 1)),
    );
    expect(
      createUploadImageSizeFromEncodedBytes(previewBytes),
      const Size(2, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CreateUploadBox(
              controller: controller,
              label: 'UPLOAD IMAGE',
              initialPreviewBytes: previewBytes,
              width: 120,
              height: 80,
              uploadOriginalImage: true,
              preserveImageAspectRatio: true,
              useMessageImageSizing: true,
              showRemoveLinkWhenFilled: false,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect(resized.width, 300);
    expect(resized.height, 200);
    expect(resized.policy, ResizeImagePolicy.fit);
    expect(resized.imageProvider, isA<MemoryImage>());
    expect(
      identical((resized.imageProvider as MemoryImage).bytes, previewBytes),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateUploadBox(
            key: const ValueKey('cropped-upload-preview'),
            controller: controller,
            label: 'UPLOAD IMAGE',
            initialPreviewBytes: previewBytes,
            width: 120,
            height: 80,
            showRemoveLinkWhenFilled: false,
            onChanged: () {},
          ),
        ),
      ),
    );

    final croppedImage = tester.widget<Image>(find.byType(Image));
    expect(croppedImage.image, isA<MemoryImage>());
  });
}

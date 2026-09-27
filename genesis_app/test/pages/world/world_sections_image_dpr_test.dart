import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  testWidgets('detail and status character images use the full screen DPR', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: const Scaffold(
            body: WorldCharacterRow(
              character: <String, dynamic>{
                'name': 'Explorer',
                'avatar': 'https://cdn.example.com/explorer.webp',
              },
              currentUid: '',
              subtitle: 'Ready',
              subtitleColor: Colors.black,
              showCharacterDetails: false,
            ),
          ),
        ),
      ),
    );

    final avatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(avatar.maxDevicePixelRatio, 3);
    expect(
      avatar.url,
      'https://cdn.example.com/explorer.webp'
      '?x-oss-process=image/resize,w_180,image/format,webp',
    );
  });

  testWidgets('World Brief image and viewer keep a DPR cap of 2', (
    tester,
  ) async {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        xlUrl: 'https://cdn.example.com/world-brief.webp',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800), devicePixelRatio: 3),
          child: Scaffold(
            body: SizedBox(
              width: 400,
              child: WorldDetailCoverImage(url: resource.displayUrl),
            ),
          ),
        ),
      ),
    );

    final sheetImage = tester.widget<GenesisStaticNetworkImage>(
      find.byType(GenesisStaticNetworkImage),
    );
    expect(sheetImage.maxDevicePixelRatio, 2);
    expect(
      sheetImage.imageUrl,
      'https://cdn.example.com/world-brief.webp'
      '?x-oss-process=image/resize,w_360,image/format,webp',
    );

    await tester.tap(find.byType(GenesisStaticNetworkImage));
    await tester.pumpAndSettle();

    final viewerImage = tester.widget<GenesisStaticNetworkImage>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('genesis-image-viewer-full-0')),
        matching: find.byType(GenesisStaticNetworkImage),
      ),
    );
    expect(viewerImage.maxDevicePixelRatio, 2);
  });
}

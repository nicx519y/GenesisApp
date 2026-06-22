import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  testWidgets('GenesisListImage renders default asset for empty URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListImage(imageUrl: '', width: 52, height: 52),
        ),
      ),
    );

    expect(_defaultListImage(), findsOneWidget);
  });

  testWidgets('GenesisListImage uses shared content image radius by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListImage(imageUrl: '', width: 52, height: 52),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, GenesisImageRadii.content);
  });

  testWidgets('GenesisListImage builds xl resize URL from display width', (
    WidgetTester tester,
  ) async {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        smUrl: 'https://cdn.example.com/photo_400_300.webp',
        xlUrl: 'https://cdn.example.com/photo_800_600.webp',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Scaffold(
            body: GenesisListImage(
              imageUrl: resource.displayUrl,
              width: 100,
              height: 75,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      image.imageUrl,
      'https://cdn.example.com/photo_800_600.webp'
      '?x-oss-process=image/resize,w_360,image/format,webp',
    );
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.placeholderFadeInDuration, Duration.zero);
  });

  test('selectGenesisImageUrl strips xl query before adding resize params', () {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        smUrl: 'https://cdn.example.com/photo-sm.webp',
        xlUrl: 'https://cdn.example.com/photo-xl.webp?old=true#frag',
      ),
    );

    expect(
      selectGenesisImageUrl(
        resource.displayUrl,
        logicalWidth: 44,
        logicalHeight: 44,
        devicePixelRatio: 1,
      ),
      'https://cdn.example.com/photo-xl.webp'
      '?x-oss-process=image/resize,w_45,image/format,webp',
    );
  });

  test('selectGenesisImageUrl uses the next greater width tier', () {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        xlUrl: 'https://cdn.example.com/exact-tier.webp',
      ),
    );

    expect(
      selectGenesisImageUrl(
        resource.displayUrl,
        logicalWidth: 90,
        logicalHeight: 90,
        devicePixelRatio: 1,
      ),
      'https://cdn.example.com/exact-tier.webp'
      '?x-oss-process=image/resize,w_180,image/format,webp',
    );
  });

  test('resizeGenesisImageUrl resizes any plain network URL', () {
    expect(
      resizeGenesisImageUrl(
        'https://cdn.example.com/map.webp?old=true#frag',
        logicalWidth: 320,
        devicePixelRatio: 3,
      ),
      'https://cdn.example.com/map.webp'
      '?x-oss-process=image/resize,w_1080,image/format,webp',
    );
  });
}

Finder _defaultListImage() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == genesisDefaultListImageAsset,
  );
}

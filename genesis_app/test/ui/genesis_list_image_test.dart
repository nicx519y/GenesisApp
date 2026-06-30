import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
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

  testWidgets('GenesisListImage uses custom placeholder asset', (tester) async {
    const placeholderAsset = 'assets/images/map_default/location_default.webp';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListImage(
            imageUrl: '',
            placeholderAsset: placeholderAsset,
          ),
        ),
      ),
    );

    expect(find.image(const AssetImage(placeholderAsset)), findsOneWidget);
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

    final image = tester.widget<GenesisStaticNetworkImage>(
      find.byType(GenesisStaticNetworkImage),
    );
    expect(
      image.imageUrl,
      'https://cdn.example.com/photo_800_600.webp'
      '?x-oss-process=image/resize,w_360,image/format,webp',
    );
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

  test(
    'selectGenesisImageUrl maps backend default image URLs to local assets',
    () {
      expect(
        selectGenesisImageUrl(
          'https://cdn.example.com/predata/L1_default.webp?old=true',
          logicalWidth: 320,
          logicalHeight: 480,
          devicePixelRatio: 2,
        ),
        'assets/images/map_default/l1_default.webp',
      );
      expect(
        selectGenesisImageUrl(
          'https://cdn.example.com/predata/l2_DEFAULT.png',
          logicalWidth: 320,
          logicalHeight: 480,
          devicePixelRatio: 2,
        ),
        'assets/images/map_default/l2_default.webp',
      );
      expect(
        selectGenesisImageUrl(
          'https://cdn.example.com/predata/location_default.webp',
          logicalWidth: null,
          logicalHeight: null,
          devicePixelRatio: 2,
        ),
        'assets/images/map_default/location_default.webp',
      );
      expect(
        selectGenesisImageUrl(
          'https://cdn.example.com/predata/root_default.webp',
          logicalWidth: null,
          logicalHeight: null,
          devicePixelRatio: 2,
        ),
        'assets/images/map_default/root_default.webp',
      );
    },
  );

  test(
    'resizeGenesisImageUrl maps backend default image URLs to local assets',
    () {
      expect(
        resizeGenesisImageUrl(
          'https://cdn.example.com/predata/ROOT_default.webp?old=true',
          logicalWidth: 320,
          devicePixelRatio: 3,
        ),
        'assets/images/map_default/root_default.webp',
      );
    },
  );

  test('local default image resolver returns null for normal network URLs', () {
    expect(
      localDefaultMapImageAssetForBackendImageUrl(
        'https://cdn.example.com/regular-map.webp',
      ),
      isNull,
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

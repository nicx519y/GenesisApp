import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
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

  testWidgets('GenesisListImage chooses the smallest sharp image candidate', (
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

    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'https://cdn.example.com/photo_400_300.webp',
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

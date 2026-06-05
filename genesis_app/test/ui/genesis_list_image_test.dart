import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';

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
}

Finder _defaultListImage() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == genesisDefaultListImageAsset,
  );
}

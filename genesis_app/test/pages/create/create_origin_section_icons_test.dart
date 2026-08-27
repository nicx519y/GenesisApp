import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('create and edit summary use the intended section icons', () async {
    expect(
      createOriginCharactersIconAsset,
      'assets/custom-icons/svg/create_origin_character.svg',
    );

    for (final asset in <String>[
      createOriginBasicsIconAsset,
      createOriginStoryEventsIconAsset,
      createOriginCharactersIconAsset,
      createOriginLocationsIconAsset,
      createOriginOpeningIconAsset,
    ]) {
      final svg = await rootBundle.loadString(asset);
      expect(svg, contains('#111111'), reason: asset);
      expect(svg, contains('stroke-width="2"'), reason: asset);
      expect(svg, isNot(contains('#666666')), reason: asset);
      expect(svg, isNot(contains('#09244B')), reason: asset);
      expect(svg, isNot(contains('#FF2442')), reason: asset);
    }
  });
}

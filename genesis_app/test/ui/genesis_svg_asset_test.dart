import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  test('SVG mapper preserves Light and applies Dark asset defaults', () {
    final semantic = GenesisSemanticColors(
      config: GenesisColorDefaults.dark,
      revision: 7,
    );
    final mapper = GenesisSvgColorMapper(
      assetName: 'assets/custom-icons/svg/user_icon.svg',
      colors: semantic,
    );

    expect(
      mapper.substitute(null, 'path', 'fill', const Color(0xFF444444)),
      GenesisColorDefaults.dark.color(
        GenesisColorToken.assetSourceByArgb[0xFF444444]!,
      ),
    );

    final lightMapper = GenesisSvgColorMapper(
      assetName: 'assets/custom-icons/svg/ruby.svg',
      colors: GenesisSemanticColors(
        config: GenesisColorDefaults.light,
        revision: 0,
      ),
    );
    expect(
      lightMapper.substitute(null, 'path', 'fill', const Color(0xFFD82B49)),
      const Color(0xFFD82B49),
    );
  });

  test('all bundled SVG fixed colors have explicit asset mappings', () {
    final files = Directory('assets')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'))
        .toList(growable: false);
    final paths = files.map((file) => file.path).toSet();
    expect(paths, GenesisSvgAssetRegistry.assetPaths);

    final colorPattern = RegExp(r'#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?');
    for (final file in files) {
      for (final match in colorPattern.allMatches(file.readAsStringSync())) {
        final hex = match.group(0)!.substring(1);
        final argb = hex.length == 6
            ? int.parse('FF$hex', radix: 16)
            : int.parse('${hex.substring(6)}${hex.substring(0, 6)}', radix: 16);
        expect(
          GenesisSvgAssetRegistry.tokenFor(file.path, Color(argb)),
          isNotNull,
          reason: '${file.path} contains unmapped #$hex',
        );
      }
    }
  });

  test('overlay SVG whites stay visible in Dark mode', () {
    final dark = GenesisSemanticColors(
      config: GenesisColorDefaults.dark,
      revision: 0,
    );
    for (final asset in <String>[
      'assets/custom-icons/svg/location_chat_ai_char_icon.svg',
      'assets/svg/position.svg',
    ]) {
      final mapper = GenesisSvgColorMapper(assetName: asset, colors: dark);
      expect(
        mapper.substitute(null, 'path', 'fill', const Color(0xFFFFFFFF)),
        const Color(0xFFFFFFFF),
      );
    }
  });

  test('bottom navigation Create SVG uses its dedicated Dark accent', () {
    final mapper = GenesisSvgColorMapper(
      assetName: 'assets/custom-icons/svg/bottom_nav_create.svg',
      colors: GenesisSemanticColors(
        config: GenesisColorDefaults.dark,
        revision: 0,
      ),
    );

    expect(
      mapper.substitute(null, 'path', 'fill', const Color(0xFFFF2442)),
      GenesisColorDefaults.dark.color(
        GenesisColorToken.bottomNavigationProminent,
      ),
    );
  });

  test('all runtime SVG asset calls use GenesisSvgAsset', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('genesis_svg_asset.dart'))
        .where((file) => file.readAsStringSync().contains('SvgPicture.asset('))
        .map((file) => file.path)
        .toList(growable: false);
    expect(offenders, isEmpty);
  });

  test('SVG mapper cache identity includes configuration revision', () {
    final first = GenesisSvgColorMapper(
      assetName: 'assets/svg/home.svg',
      colors: GenesisSemanticColors(
        config: GenesisColorDefaults.light,
        revision: 1,
      ),
    );
    final same = GenesisSvgColorMapper(
      assetName: 'assets/svg/home.svg',
      colors: GenesisSemanticColors(
        config: GenesisColorDefaults.light,
        revision: 1,
      ),
    );
    final revised = GenesisSvgColorMapper(
      assetName: 'assets/svg/home.svg',
      colors: GenesisSemanticColors(
        config: GenesisColorDefaults.light,
        revision: 2,
      ),
    );

    expect(first, same);
    expect(first, isNot(revised));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  test('width and height share one readable resize and WebP syntax', () {
    expect(
      buildGenesisCdnResizeUrl('https://cdn.example/photo.jpg', width: 180),
      'https://cdn.example/photo.jpg?x-oss-process=image/resize,w_180/format,webp',
    );
    expect(
      buildGenesisCdnResizeUrl('https://cdn.example/photo.jpg', height: 400),
      'https://cdn.example/photo.jpg?x-oss-process=image/resize,h_400/format,webp',
    );
  });

  for (final process in [
    'image/resize,w_1080,image/format,webp',
    Uri.encodeQueryComponent('image/resize,h_400/format,webp'),
  ]) {
    test(
      'replaces existing processing without losing other parameters: $process',
      () {
        final source =
            'https://cdn.example/a%20b.jpg?token=a%2Bb&tag=one&tag=two&x-oss-process=$process#old';
        final resized = buildGenesisCdnResizeUrl(source, width: 360);
        final uri = Uri.parse(resized);
        expect(uri.path, '/a%20b.jpg');
        expect(uri.queryParameters['token'], 'a+b');
        expect(uri.queryParametersAll['tag'], ['one', 'two']);
        expect(uri.queryParametersAll['x-oss-process'], [
          'image/resize,w_360/format,webp',
        ]);
        expect(uri.hasFragment, isFalse);
        expect(buildGenesisCdnResizeUrl(resized, width: 360), resized);
      },
    );
  }

  test('width and fixed-height entry points both preserve query parameters', () {
    const source = 'https://cdn.example/shared.jpg?token=abc&x-oss-process=old';
    expect(
      resizeGenesisImageUrl(source, logicalWidth: 100, devicePixelRatio: 3),
      'https://cdn.example/shared.jpg?token=abc&x-oss-process=image/resize,w_360/format,webp',
    );
    expect(
      resizeGenesisImageUrlToHeight(
        source,
        logicalHeight: 200,
        devicePixelRatio: 3,
      ),
      'https://cdn.example/shared.jpg?token=abc&x-oss-process=image/resize,h_400/format,webp',
    );
  });

  test('requires one valid pixel dimension', () {
    expect(
      () => buildGenesisCdnResizeUrl('https://cdn.example/a.jpg'),
      throwsArgumentError,
    );
    expect(
      () => buildGenesisCdnResizeUrl(
        'https://cdn.example/a.jpg',
        width: 90,
        height: 90,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildGenesisCdnResizeUrl('https://cdn.example/a.jpg', width: 0),
      throwsRangeError,
    );
  });
}

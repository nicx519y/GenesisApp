import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.mock_dataset%253Avalue/map_image.dart';

// The inherited implementation creates a real dart:io client. Scope it to the
// lease test so Flutter's HTTP test override remains intact outside this zone.
class _LeaseHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('serves a decodable lease image, denies foreign reads, releases socket and cache', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      var owner = true;
      final released = <String>[];
      final image = await WorldMapImage.open(
        requireOwner: () async { if (!owner) throw StateError('foreign owner'); },
        releaseCache: (url) async { released.add(url); },
      );
      final client = HttpClient();
      ui.Codec? codec;
      ui.Image? decoded;
      try {
        final response = await (await client.getUrl(Uri.parse(image.url))).close();
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.contentType?.mimeType, 'image/webp');
        final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
        codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        decoded = (await codec.getNextFrame()).image;
        expect(decoded.width, greaterThan(0));
        expect(decoded.height, greaterThan(0));
        owner = false;
        final rejected = await (await client.getUrl(Uri.parse(image.url))).close();
        expect(rejected.statusCode, HttpStatus.forbidden);
        await rejected.drain<void>();
        owner = true;
        final missing = await (await client.getUrl(Uri.parse('${image.url}/foreign'))).close();
        expect(missing.statusCode, HttpStatus.notFound);
        await missing.drain<void>();
      } finally {
        decoded?.dispose();
        codec?.dispose();
        client.close(force: true);
        await image.close();
      }
      expect(image.closed, isTrue);
      expect(released, [image.url]);
      await image.close();
      expect(released, [image.url]);
      final probe = HttpClient()..connectionTimeout = const Duration(seconds: 1);
      try {
        await expectLater(probe.getUrl(Uri.parse(image.url)), throwsA(isA<SocketException>()));
      } finally { probe.close(force: true); }
    }, _LeaseHttpOverrides());
  });
  test('empty image cannot acquire a server', () async {
    await expectLater(WorldMapImage.open(
      requireOwner: () async {}, load: () async => Uint8List(0),
    ), throwsStateError);
  });
  test('failed cache release remains retryable after socket closure', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      var fail = true;
      final released = <String>[];
      final image = await WorldMapImage.open(
        requireOwner: () async {}, load: () async => Uint8List.fromList([1]),
        releaseCache: (url) async {
          if (fail) throw StateError('cache release');
          released.add(url);
        },
      );
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(Uri.parse(image.url))).close();
        await response.drain<void>();
        await expectLater(image.close(), throwsStateError);
        expect(image.closed, isTrue);
        fail = false;
      } finally {
        fail = false;
        client.close(force: true);
        await image.close();
      }
      expect(released, [image.url]);
    }, _LeaseHttpOverrides());
  });
  test('lease HTTP scope restores its caller after asynchronous failure', () async {
    final previous = HttpOverrides.current;
    final overrides = _LeaseHttpOverrides();
    final failure = StateError('lease test failed');
    await expectLater(
      HttpOverrides.runWithHttpOverrides(() async {
        expect(HttpOverrides.current, same(overrides));
        await Future<void>.delayed(Duration.zero);
        expect(HttpOverrides.current, same(overrides));
        throw failure;
      }, overrides),
      throwsA(same(failure)),
    );
    expect(HttpOverrides.current, same(previous));
    await HttpOverrides.runWithHttpOverrides(() async {
      expect(HttpOverrides.current, same(overrides));
    }, overrides);
    expect(HttpOverrides.current, same(previous));
  });
}

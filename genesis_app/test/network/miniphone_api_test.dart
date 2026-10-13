import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/network/v1/genesis_v1_api.dart';

class _Transport implements HttpTransport {
  Object response = {
    'err_no': 0,
    'data': {
      'background_image': 'https://cdn.example/custom.png',
      'default_background_images': [
        {'image_url': 'https://cdn.example/2.png', 'title': 'Second'},
        {'image_url': 'https://cdn.example/1.png', 'title': 'First'},
      ],
    },
  };
  final requests = <TransportRequest>[];
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode(response),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Transport transport;
  late GenesisV1Api api;
  setUp(() {
    transport = _Transport();
    api = GenesisV1Api(
      ApiClient(baseUrl: 'https://api.example/api/', transport: transport),
    );
  });

  test(
    'GET sends world query and maps current image and ordered catalogue',
    () async {
      final info = await api.world.miniphoneInfo(worldId: ' w_1 ');
      final request = transport.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/world/miniphoneinfo');
      expect(request.uri.queryParameters, {'world_id': 'w_1'});
      expect(request.bodyBytes, isNull);
      expect(info.backgroundImage, 'https://cdn.example/custom.png');
      expect(info.wallpapers.map((w) => w.title), ['Second', 'First']);
    },
  );

  test(
    'POST preserves required empty background and accepts empty success data',
    () async {
      transport.response = {'err_no': 0, 'data': {}};
      for (final url in ['', 'https://cdn.example/image.webp?size=800']) {
        await api.world.setMiniphoneBackground(
          worldId: 'w_1',
          backgroundImage: url,
        );
        final request = transport.requests.last;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/world/setminiphonebackground');
        expect(jsonDecode(utf8.decode(request.bodyBytes!)), {
          'world_id': 'w_1',
          'background_image': url,
        });
      }
    },
  );

  test('GET and POST propagate HTTP 200 business errors', () async {
    transport.response = {
      'err_no': 4004,
      'err_msg': 'param invalid',
      'data': {},
    };
    final error = isA<ApiException>().having((e) => e.code, 'code', 4004);
    await expectLater(api.world.miniphoneInfo(worldId: 'w_1'), throwsA(error));
    await expectLater(
      api.world.setMiniphoneBackground(worldId: 'w_1', backgroundImage: ''),
      throwsA(error),
    );
  });

  test('invalid IDs and URLs never reach transport', () async {
    await expectLater(
      api.world.miniphoneInfo(worldId: '  '),
      throwsArgumentError,
    );
    expect(
      () => api.world.setMiniphoneBackground(worldId: '', backgroundImage: ''),
      throwsArgumentError,
    );
    for (final url in [
      'file:///tmp/a.png',
      'https://user:pass@cdn.example/a',
      'https://@cdn.example/a',
      ' https://cdn.example/a',
      'https://cdn.example/a ',
      'https:///a',
      'assets/a.png',
      'https://cdn.example/${'a' * 513}',
    ]) {
      expect(
        () => api.world.setMiniphoneBackground(
          worldId: 'w_1',
          backgroundImage: url,
        ),
        throwsArgumentError,
        reason: url,
      );
    }
    expect(transport.requests, isEmpty);
    expect(isValidMiniphoneBackground('http://cdn.example/a'), isTrue);
    expect(
      isValidMiniphoneBackground(
        'https://cdn.example/${'a' * (512 - 'https://cdn.example/'.length)}',
      ),
      isTrue,
    );
  });

  test('empty values are valid but malformed required data is not hidden', () {
    final info = MiniphoneInfo.fromJson({
      'background_image': '',
      'default_background_images': [],
    });
    expect(info.backgroundImage, isEmpty);
    expect(info.wallpapers, isEmpty);
    for (final json in <Map<String, dynamic>>[
      {},
      {'background_image': null, 'default_background_images': []},
      {'background_image': '', 'default_background_images': null},
      {
        'background_image': '',
        'default_background_images': [
          {'image_url': 'https://cdn.example/a'},
        ],
      },
    ]) {
      expect(() => MiniphoneInfo.fromJson(json), throwsFormatException);
    }
  });

  test(
    'facade and mock persist per account across Worlds and clear via empty string',
    () async {
      final facade = GenesisApi(useMock: true);
      final worlds = await facade.v1.world.list();
      final ids = (worlds['list'] as List)
          .map((w) => (w['info']['world_id'] as String))
          .toList();
      expect(ids.length, greaterThanOrEqualTo(2));
      // The local mock's existing OAuth route authenticates its fixture account.
      await ApiClient(
        baseUrl: 'https://api.example/api/',
        transport: LocalMockGenesisTransport.instance,
      ).post<Object?>(
        'v1/user/oauth/google',
        body: {'id_token': 'mock-wallpaper-token'},
      );
      await facade.setMiniphoneBackground(
        worldId: ids.first,
        backgroundImage: 'https://cdn.example/upload.png',
      );
      expect(
        (await facade.fetchMiniphoneInfo(worldId: ids[1])).backgroundImage,
        'https://cdn.example/upload.png',
      );
      await facade.setMiniphoneBackground(worldId: ids[1], backgroundImage: '');
      final info = await facade.fetchMiniphoneInfo(worldId: ids.first);
      expect(info.backgroundImage, isEmpty);
      expect(info.wallpapers, isEmpty);
    },
  );
}

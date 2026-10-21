import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/network/v1/genesis_v1_api.dart';

Map<String, dynamic> _catalogJson() => {
  'pre_url': 'https://cdn-001.worldo.ai/predata/music/',
  'list': [
    <String, dynamic>{
      'file': '001.mp3',
      'source_worldo_id': 'o_D91RHR',
      'source_worldo_name': 'My Hero Academia',
      'artist': 'Katsuki Bakugo',
      'title': 'Number One Lungs',
      'cover_url': 'https://cdn.example/cover.jpg?resize=800',
      'like_cnt': 1234,
      'is_liked': false,
    },
  ],
};

class _Transport implements HttpTransport {
  Object response = {'err_no': 0, 'err_msg': 'succ', 'data': _catalogJson()};
  TransportRequest? request;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    this.request = request;
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode(response),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'guest list sends no parameters and maps the supplied music contract',
    () async {
      final transport = _Transport();
      final api = GenesisV1Api(
        ApiClient(baseUrl: 'https://api.example/api/', transport: transport),
      );
      final catalog = await api.music.list();
      expect(transport.request!.method, 'GET');
      expect(transport.request!.uri.path, '/api/v1/music/list');
      expect(transport.request!.uri.query, isEmpty);
      expect(transport.request!.bodyBytes, isNull);
      final track = catalog.tracks.single;
      expect(track.audioUrl, 'https://cdn-001.worldo.ai/predata/music/001.mp3');
      expect(track.sourceWorldoId, 'o_D91RHR');
      expect(track.sourceWorldoName, 'My Hero Academia');
      expect(track.artist, 'Katsuki Bakugo');
      expect(track.title, 'Number One Lungs');
      expect(track.coverUrl, 'https://cdn.example/cover.jpg');
      expect(track.likeCount, 1234);
      expect(track.isLiked, isFalse);
    },
  );
  test(
    'business errors remain errors instead of becoming empty catalogues',
    () async {
      final transport = _Transport()
        ..response = {'err_no': 3103, 'err_msg': 'Unavailable', 'data': {}};
      final api = GenesisV1Api(
        ApiClient(baseUrl: 'https://api.example/api/', transport: transport),
      );
      await expectLater(
        api.music.list(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 3103)),
      );
    },
  );
  test(
    'preserves server order and accepts an empty list without assuming 100',
    () {
      final json = _catalogJson();
      final first = (json['list'] as List).single as Map<String, dynamic>;
      json['list'] = [
        {...first, 'file': '002.mp3'},
        first,
      ];
      expect(MusicCatalog.fromJson(json).tracks.map((t) => t.file), [
        '002.mp3',
        '001.mp3',
      ]);
      json['list'] = [];
      expect(MusicCatalog.fromJson(json).tracks, isEmpty);
    },
  );
  test('malformed required catalogue data is not silently dropped', () {
    for (final json in [
      {..._catalogJson(), 'list': null},
      {
        ..._catalogJson(),
        'list': ['invalid'],
      },
      {..._catalogJson(), 'pre_url': 'not-a-url'},
      {
        ..._catalogJson(),
        'list': [
          {'file': '001.mp3'},
        ],
      },
    ]) {
      expect(() => MusicCatalog.fromJson(json), throwsFormatException);
    }
  });
  test('catalogue preserves int64 counts and current-user state', () {
    final json = _catalogJson();
    final track = (json['list'] as List).single as Map<String, dynamic>;
    track['like_cnt'] = 9223372036854775807;
    track['is_liked'] = true;
    final parsed = MusicCatalog.fromJson(json).tracks.single;
    expect(parsed.likeCount, 9223372036854775807);
    expect(parsed.isLiked, isTrue);
  });

  test('catalogue requires nonnegative integer counts and boolean state', () {
    for (final field in ['like_cnt', 'is_liked']) {
      final invalidValues = field == 'like_cnt'
          ? [null, -1, 1.5, '10', true]
          : [null, 0, 'false'];
      for (final value in invalidValues) {
        final json = _catalogJson();
        ((json['list'] as List).single as Map<String, dynamic>)[field] = value;
        expect(() => MusicCatalog.fromJson(json), throwsFormatException);
      }
      final json = _catalogJson();
      ((json['list'] as List).single as Map<String, dynamic>).remove(field);
      expect(() => MusicCatalog.fromJson(json), throwsFormatException);
    }
  });

  test('facade routes music to the explicit empty mock catalogue', () async {
    final catalog = await GenesisApi(useMock: true).fetchMusicCatalog();
    expect(catalog.tracks, isEmpty);
    expect(catalog.preUrl, 'https://cdn-001.worldo.ai/predata/music/');
  });

  test(
    'like/unlike send exact file in JSON and status uses a GET query',
    () async {
      final transport = _Transport()..response = {'err_no': 0, 'data': {}};
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: transport,
        ),
      );
      await api.likeMusic(file: '001.mp3');
      expect(transport.request!.method, 'POST');
      expect(transport.request!.uri.path, '/api/v1/music/like');
      expect(jsonDecode(utf8.decode(transport.request!.bodyBytes!)), {
        'file': '001.mp3',
      });
      await api.unlikeMusic(file: '001.mp3');
      expect(transport.request!.method, 'POST');
      expect(transport.request!.uri.path, '/api/v1/music/unlike');
      expect(jsonDecode(utf8.decode(transport.request!.bodyBytes!)), {
        'file': '001.mp3',
      });
      for (final liked in [true, false]) {
        transport.response = {
          'err_no': 0,
          'data': {'file': '001.mp3', 'is_liked': liked},
        };
        final status = await api.fetchMusicLikeStatus(file: '001.mp3');
        expect(transport.request!.method, 'GET');
        expect(transport.request!.uri.path, '/api/v1/music/like_status');
        expect(transport.request!.uri.queryParameters, {'file': '001.mp3'});
        expect(transport.request!.bodyBytes, isNull);
        expect(status.file, '001.mp3');
        expect(status.isLiked, liked);
      }
    },
  );

  test(
    'all like endpoints preserve the business err_msg on HTTP 200',
    () async {
      final transport = _Transport()
        ..response = {'err_no': 10001, 'err_msg': '请先登录', 'data': {}};
      final api = GenesisV1Api(
        ApiClient(baseUrl: 'https://api.example/api/', transport: transport),
      );
      final error = isA<ApiException>()
          .having((e) => e.code, 'code', 10001)
          .having((e) => e.message, 'message', '请先登录');
      await expectLater(api.music.like(file: '001.mp3'), throwsA(error));
      await expectLater(api.music.unlike(file: '001.mp3'), throwsA(error));
      await expectLater(api.music.likeStatus(file: '001.mp3'), throwsA(error));
    },
  );

  test(
    'like status requires a boolean instead of silently treating malformed data as unliked',
    () {
      for (final liked in [null, 1, 'true']) {
        expect(
          () =>
              MusicLikeStatus.fromJson({'file': '001.mp3', 'is_liked': liked}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mock likes are idempotent, authenticated, and reject file aliases',
    () async {
      final api = GenesisV1Api(
        ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: LocalMockGenesisTransport.instance,
          defaultHeaders: {'Authorization': 'Bearer test-music-session'},
        ),
      );
      await api.music.unlike(file: '001.mp3');
      expect((await api.music.likeStatus(file: '001.mp3')).isLiked, isFalse);
      await api.music.like(file: '001.mp3');
      await api.music.like(file: '001.mp3');
      expect((await api.music.likeStatus(file: '001.mp3')).isLiked, isTrue);
      await api.music.unlike(file: '001.mp3');
      await api.music.unlike(file: '001.mp3');
      expect((await api.music.likeStatus(file: '001.mp3')).isLiked, isFalse);
      for (final file in ['../001.mp3', '001.MP3', '1.mp3', '101.mp3']) {
        await expectLater(
          api.music.like(file: file),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 4004)),
        );
      }
      final guest = GenesisV1Api(
        ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: LocalMockGenesisTransport.instance,
        ),
      );
      final loginError = throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 10001),
      );
      await expectLater(guest.music.likeStatus(file: '001.mp3'), loginError);
      await expectLater(guest.music.like(file: '001.mp3'), loginError);
      await expectLater(guest.music.unlike(file: '001.mp3'), loginError);
    },
  );
}

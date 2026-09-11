import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_feature_quota_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

const _largeInt = 9007199254740993;

Map<String, Object?> _quota({
  String scope = 'trial_lifetime',
  bool unlimited = false,
  Object? limit = 3,
  Object? used = 1,
  Object? remaining = 2,
  Object? resetAt,
  bool includeResetAt = true,
}) => {
  'scope': scope,
  'unlimited': unlimited,
  'limit': limit,
  'used': used,
  'remaining': remaining,
  if (includeResetAt) 'reset_at': resetAt,
};

Map<String, Object?> _quotas({
  Object? membershipStatus = 0,
  Object? inspiration,
  Object? conversationEdit,
}) => {
  'membership_status': membershipStatus,
  'inspiration': inspiration ?? _quota(),
  'conversation_edit':
      conversationEdit ??
      _quota(
        scope: 'member_daily',
        limit: _largeInt,
        used: _largeInt - 2,
        remaining: 2,
        resetAt: 1798761600,
      ),
};

class _QuotaTransport implements HttpTransport {
  Object? response = {'err_no': 0, 'err_msg': 'succ', 'data': _quotas()};
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {
        'content-type': 'application/json',
        'cache-control': 'no-store',
      },
      body: jsonEncode(response),
    );
  }
}

ChatroomHttpApi _api(_QuotaTransport transport, {bool authenticated = false}) =>
    ChatroomHttpApi(
      ApiClient(
        baseUrl: 'https://chat.test/',
        transport: transport,
        requestHeaderProvider: authenticated
            ? () async => {'Authorization': 'Bearer token'}
            : null,
      ),
    );

void main() {
  test(
    'GET preserves auth, cancellation, path, and int64 quota values',
    () async {
      final transport = _QuotaTransport();
      final token = NetworkCancellationToken();
      final result = await _api(
        transport,
        authenticated: true,
      ).getFeatureQuotas(cancellationToken: token);

      final request = transport.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/aitown-chat/api/v1/feature-quotas');
      expect(request.uri.queryParameters, isEmpty);
      expect(request.bodyBytes, isNull);
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.cancellationToken, isNotNull);
      expect(request.cancellationToken, isNot(same(token)));

      expect(result.membershipStatus, 0);
      expect(result.inspiration.scope, ChatroomFeatureQuotaScope.trialLifetime);
      expect(
        result.conversationEdit.scope,
        ChatroomFeatureQuotaScope.memberDaily,
      );
      expect(result.conversationEdit.limit, _largeInt);
      expect(result.conversationEdit.used, _largeInt - 2);
      expect(result.conversationEdit.remaining, 2);
      expect(result.conversationEdit.resetAtUnixSeconds, 1798761600);

      token.cancel();
      await expectLater(
        _api(transport).getFeatureQuotas(cancellationToken: token),
        throwsA(isA<NetworkRequestCancelledException>()),
      );
      expect(transport.requests, hasLength(1));
    },
  );

  test('parses unlimited nullable quota fields without invented defaults', () {
    final result = ChatroomFeatureQuotas.fromJson(
      _quotas(
        membershipStatus: 2,
        inspiration: _quota(
          scope: 'member_unlimited',
          unlimited: true,
          limit: null,
          used: 12,
          remaining: null,
          resetAt: null,
        ),
      ),
    );

    expect(result.membershipStatus, 2);
    expect(result.inspiration.scope, ChatroomFeatureQuotaScope.memberUnlimited);
    expect(result.inspiration.unlimited, isTrue);
    expect(result.inspiration.limit, isNull);
    expect(result.inspiration.used, 12);
    expect(result.inspiration.remaining, isNull);
    expect(result.inspiration.resetAtUnixSeconds, isNull);
    expect(
      result.toJson(),
      _quotas(
        membershipStatus: 2,
        inspiration: _quota(
          scope: 'member_unlimited',
          unlimited: true,
          limit: null,
          used: 12,
          remaining: null,
          resetAt: null,
        ),
      ),
    );
  });

  test(
    'rejects malformed success data instead of fabricating quotas',
    () async {
      final invalidData = <Object?>[
        _quotas(membershipStatus: 3),
        _quotas(inspiration: _quota(scope: 'weekly')),
        _quotas(inspiration: _quota(limit: -1)),
        _quotas(inspiration: _quota(used: 1.5)),
        _quotas(inspiration: _quota(remaining: '2')),
        _quotas(inspiration: _quota(includeResetAt: false)),
        <String, Object?>{},
      ];

      for (final data in invalidData) {
        final transport = _QuotaTransport()
          ..response = {'err_no': 0, 'err_msg': 'succ', 'data': data};
        await expectLater(
          _api(transport).getFeatureQuotas(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiExceptionKind.response,
            ),
          ),
        );
      }
    },
  );

  test('preserves quota business error codes and messages', () async {
    for (final entry in const {
      10001: 'Unauthorized',
      5002: 'Usage lookup failed',
      5003: 'Invalid membership data',
    }.entries) {
      final transport = _QuotaTransport()
        ..response = {
          'err_no': entry.key,
          'err_msg': entry.value,
          'data': <String, Object?>{},
        };
      await expectLater(
        _api(transport).getFeatureQuotas(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiExceptionKind.business)
              .having((error) => error.code, 'code', entry.key)
              .having((error) => error.message, 'message', entry.value),
        ),
      );
    }
  });

  test('rejects a response without the v1 envelope', () async {
    final transport = _QuotaTransport()..response = _quotas();
    await expectLater(
      _api(transport).getFeatureQuotas(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiExceptionKind.response)
            .having(
              (error) => error.message,
              'message',
              'Invalid feature quotas envelope',
            ),
      ),
    );
  });
}

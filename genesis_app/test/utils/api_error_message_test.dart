import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/v1/v1_api_resource.dart';
import 'package:genesis_flutter_android/utils/api_error_message.dart';

void main() {
  test('v1 server err_msg is shown without diagnostic fields', () {
    Object? error;
    try {
      handleV1ResponseErrNo({
        'data': <String, Object?>{},
        'err_msg': 'user banned',
        'err_no': 10013,
      });
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<ApiException>());
    expect(apiErrorMessage(error!), 'user banned');
    expect(loginErrorMessage(error), 'user banned');
    expect(error.toString(), contains('(code=10013)'));
  });

  test('nonempty server copy keeps its original text', () {
    expect(
      apiErrorMessage(
        ApiException(message: 'diagnostic', serverErrMsg: ' user banned '),
      ),
      ' user banned ',
    );
  });

  test('legacy err_str remains a server supplied message', () {
    Object? error;
    try {
      handleV1ResponseErrNo({'err_no': 77, 'err_str': 'legacy failure'});
    } catch (caught) {
      error = caught;
    }

    expect(apiErrorMessage(error!), 'legacy failure');
  });

  test('legacy HTTP error string remains server supplied copy', () {
    expect(
      serverErrorMessageFromResponse({'error': 'legacy access denied'}),
      'legacy access denied',
    );
    expect(
      serverErrorMessageFromResponse({
        'error': {'code': 403},
      }),
      isNull,
    );
  });

  test('empty err_msg falls back to legacy errStr, then local copy', () {
    expect(
      () => handleV1ResponseErrNo({
        'err_no': 77,
        'err_msg': '',
        'errStr': 'older server failure',
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => apiErrorMessage(error),
          'toast message',
          'older server failure',
        ),
      ),
    );
    expect(
      () => handleV1ResponseErrNo({'err_no': 77, 'err_msg': ''}),
      throwsA(
        isA<ApiException>().having(
          (error) => apiErrorMessage(error),
          'toast message',
          'Something went wrong',
        ),
      ),
    );
  });

  test('client-created business exception is not treated as err_msg', () {
    final error = ApiException(
      message: 'internal permission check',
      code: 10011,
      kind: ApiExceptionKind.business,
    );
    expect(apiErrorMessage(error), 'Something went wrong');
    expect(loginErrorMessage(error), 'Sign-in failed. Please try again.');
  });

  test('HTTP error exposes err_msg only when the response contains one', () {
    final response = ApiResponse(
      statusCode: 403,
      headers: const <String, String>{},
      body: '{"err_msg":"access denied"}',
      bodyBytes: const <int>[],
      data: const <String, Object?>{'err_msg': 'access denied'},
      uri: Uri.parse('https://api.example.com/v1/user'),
    );

    expect(
      () => ApiClient.defaultResponseProcessor(response),
      throwsA(
        isA<ApiException>().having(
          (error) => apiErrorMessage(error),
          'toast message',
          'access denied',
        ),
      ),
    );
  });

  test('network and timeout errors use local login copy', () {
    expect(
      loginErrorMessage(
        ApiException(
          message: 'Request failed',
          kind: ApiExceptionKind.transport,
        ),
      ),
      'Unable to connect. Check your internet connection and try again.',
    );
    expect(
      loginErrorMessage(TimeoutException('internal timeout')),
      'Sign-in timed out. Please try again.',
    );
  });
}

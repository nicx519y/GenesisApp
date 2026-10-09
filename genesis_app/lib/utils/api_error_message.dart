import 'dart:async';

import '../network/api_exception.dart';

String apiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong',
}) {
  if (error is ApiException) {
    final message = error.serverErrMsg;
    if (message != null && message.trim().isNotEmpty) return message;
  }
  return fallback;
}

String loginErrorMessage(Object error) {
  const fallback = 'Sign-in failed. Please try again.';
  final serverMessage = apiErrorMessage(error, fallback: '');
  if (serverMessage.isNotEmpty) return serverMessage;
  if (error is TimeoutException ||
      error is ApiException && error.kind == ApiExceptionKind.timeout) {
    return 'Sign-in timed out. Please try again.';
  }
  if (error is ApiException) {
    if (error.kind == ApiExceptionKind.transport) {
      return 'Unable to connect. Check your internet connection and try again.';
    }
    if (error.kind == ApiExceptionKind.httpStatus ||
        error.kind == ApiExceptionKind.gatewayAuth ||
        error.kind == ApiExceptionKind.response) {
      return 'Sign-in is temporarily unavailable. Please try again later.';
    }
  }
  return fallback;
}

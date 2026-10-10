import 'dart:async';

import '../l10n/genesis_l10n.dart';
import '../network/api_exception.dart';

String apiErrorMessage(Object error, {String? fallback}) {
  if (error is ApiException) {
    final message = error.serverErrMsg;
    if (message != null && message.trim().isNotEmpty) return message;
  }
  return fallback ?? GenesisL10n.current.genericError;
}

String loginErrorMessage(Object error) {
  final fallback = GenesisL10n.current.meSignInFailed;
  final serverMessage = apiErrorMessage(error, fallback: '');
  if (serverMessage.isNotEmpty) return serverMessage;
  if (error is TimeoutException ||
      error is ApiException && error.kind == ApiExceptionKind.timeout) {
    return GenesisL10n.current.loginTimedOut;
  }
  if (error is ApiException) {
    if (error.kind == ApiExceptionKind.transport) {
      return GenesisL10n.current.loginConnectionFailed;
    }
    if (error.kind == ApiExceptionKind.httpStatus ||
        error.kind == ApiExceptionKind.gatewayAuth ||
        error.kind == ApiExceptionKind.response) {
      return GenesisL10n.current.loginTemporarilyUnavailable;
    }
  }
  return fallback;
}

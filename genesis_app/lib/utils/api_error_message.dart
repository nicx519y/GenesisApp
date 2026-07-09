import '../network/api_exception.dart';

String apiErrorMessage(Object error, {String fallback = 'Request failed'}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return fallback;
}

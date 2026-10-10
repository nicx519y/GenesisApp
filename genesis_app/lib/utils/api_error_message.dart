import '../l10n/genesis_l10n.dart';
import '../network/api_exception.dart';

String apiErrorMessage(Object error, {String? fallback}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return fallback ?? GenesisL10n.current.meRequestFailed;
}

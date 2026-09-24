import 'v1_api_resource.dart';

class EventV1Api extends V1ApiResource {
  const EventV1Api(super.client);

  /// POST /api/v1/event/report
  Future<void> report({
    required String event,
    required String environment,
    required int occurredAtSeconds,
    required Map<String, String> params,
    String? transactionId,
  }) async {
    final normalizedEvent = event.trim();
    if (normalizedEvent.isEmpty) {
      throw ArgumentError.value(event, 'event', 'must not be empty');
    }
    final normalizedEnvironment = environment.trim().toLowerCase();
    if (normalizedEnvironment != 'sandbox' &&
        normalizedEnvironment != 'production') {
      throw ArgumentError.value(
        environment,
        'environment',
        'must be sandbox or production',
      );
    }
    if (occurredAtSeconds <= 0) {
      throw ArgumentError.value(
        occurredAtSeconds,
        'occurredAtSeconds',
        'must be a positive UTC Unix timestamp in seconds',
      );
    }
    final normalizedTransactionId = transactionId?.trim();
    await postData(
      'event/report',
      v1Body(<String, Object?>{
        'event': normalizedEvent,
        'environment': normalizedEnvironment,
        'occurred_at': occurredAtSeconds,
        if (normalizedTransactionId?.isNotEmpty == true)
          'transaction_id': normalizedTransactionId,
        if (params.isNotEmpty) 'params': params,
      }),
    );
  }
}

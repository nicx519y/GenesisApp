enum GemBalanceAlertKind { insufficient, low }

class GemBalanceAlert {
  const GemBalanceAlert({
    required this.kind,
    this.balanceCent = 0,
    this.message = '',
    this.analyticsTrigger,
  });

  final GemBalanceAlertKind kind;
  final int balanceCent;
  final String message;
  final String? analyticsTrigger;
}

bool isGemBalanceFailureCode(Object? code) =>
    const {'3001', '21001'}.contains('$code'.trim());

/// The credential belongs to the request/connection that received the event.
typedef GemBalanceAlertHandler =
    void Function(GemBalanceAlert alert, String? requestAuthorization);

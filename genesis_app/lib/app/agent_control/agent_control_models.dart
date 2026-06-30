class AgentControlRequest {
  const AgentControlRequest({
    required this.id,
    required this.method,
    required this.params,
    required this.timeoutMs,
    required this.dryRun,
  });

  factory AgentControlRequest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const AgentControlException(
        code: 'invalid_request',
        message: 'Request body must be a JSON object.',
      );
    }
    final json = Map<String, Object?>.from(raw);
    final method = json['method']?.toString().trim() ?? '';
    if (method.isEmpty) {
      throw const AgentControlException(
        code: 'invalid_method',
        message: 'method is required.',
      );
    }
    final params = json['params'];
    return AgentControlRequest(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : method,
      method: method,
      params: params is Map ? Map<String, Object?>.from(params) : const {},
      timeoutMs: _positiveInt(json['timeoutMs']) ?? 10000,
      dryRun: _boolValue(json['dryRun']),
    );
  }

  final String id;
  final String method;
  final Map<String, Object?> params;
  final int timeoutMs;
  final bool dryRun;
}

class AgentControlResponse {
  const AgentControlResponse({
    required this.id,
    required this.ok,
    required this.appState,
    this.result,
    this.error,
  });

  final String id;
  final bool ok;
  final Object? result;
  final Map<String, Object?>? error;
  final Map<String, Object?> appState;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'ok': ok,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      'appState': appState,
    };
  }
}

class AgentControlException implements Exception {
  const AgentControlException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() => 'AgentControlException($code, $message)';
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

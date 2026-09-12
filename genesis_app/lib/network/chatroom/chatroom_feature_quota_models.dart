import '../api_exception.dart';

enum ChatroomFeatureQuotaScope {
  trialLifetime('trial_lifetime'),
  memberDaily('member_daily'),
  memberUnlimited('member_unlimited');

  const ChatroomFeatureQuotaScope(this.wireName);

  final String wireName;

  static ChatroomFeatureQuotaScope fromJson(Object? value) {
    for (final scope in values) {
      if (value == scope.wireName) return scope;
    }
    throw const FormatException('Invalid feature quota scope');
  }
}

class ChatroomFeatureQuotaSummary {
  const ChatroomFeatureQuotaSummary({
    required this.scope,
    required this.unlimited,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetAtUnixSeconds,
  });

  factory ChatroomFeatureQuotaSummary.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid feature quota summary');
    }

    Object? requiredField(String key) {
      if (!value.containsKey(key)) {
        throw FormatException('Missing feature quota field: $key');
      }
      return value[key];
    }

    final unlimited = requiredField('unlimited');
    if (unlimited is! bool) {
      throw const FormatException('Invalid feature quota unlimited');
    }

    return ChatroomFeatureQuotaSummary(
      scope: ChatroomFeatureQuotaScope.fromJson(requiredField('scope')),
      unlimited: unlimited,
      limit: _nullableNonNegativeInt(requiredField('limit'), 'limit'),
      used: _nonNegativeInt(requiredField('used'), 'used'),
      remaining: _nullableNonNegativeInt(
        requiredField('remaining'),
        'remaining',
      ),
      resetAtUnixSeconds: _nullableInt(requiredField('reset_at'), 'reset_at'),
    );
  }

  final ChatroomFeatureQuotaScope scope;
  final bool unlimited;
  final int? limit;
  final int used;
  final int? remaining;
  final int? resetAtUnixSeconds;

  Map<String, Object?> toJson() => {
    'scope': scope.wireName,
    'unlimited': unlimited,
    'limit': limit,
    'used': used,
    'remaining': remaining,
    'reset_at': resetAtUnixSeconds,
  };
}

class ChatroomFeatureQuotas {
  const ChatroomFeatureQuotas({
    required this.membershipStatus,
    bool? isMember,
    required this.inspiration,
    required this.conversationEdit,
  }) : isMember = isMember ?? membershipStatus == 1;

  factory ChatroomFeatureQuotas.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid feature quotas response');
    }
    if (!value.containsKey('membership_status') ||
        !value.containsKey('inspiration') ||
        !value.containsKey('conversation_edit')) {
      throw const FormatException('Missing feature quotas field');
    }
    final isMember = value['is_member'];
    if (isMember is! bool) {
      throw const FormatException('Invalid feature quota is_member');
    }
    final membershipStatus = value['membership_status'];
    if (membershipStatus is! int ||
        !const {0, 1, 2}.contains(membershipStatus)) {
      throw const FormatException('Invalid feature quota membership status');
    }
    return ChatroomFeatureQuotas(
      membershipStatus: membershipStatus,
      isMember: isMember,
      inspiration: ChatroomFeatureQuotaSummary.fromJson(value['inspiration']),
      conversationEdit: ChatroomFeatureQuotaSummary.fromJson(
        value['conversation_edit'],
      ),
    );
  }

  final int membershipStatus;
  final bool isMember;
  final ChatroomFeatureQuotaSummary inspiration;
  final ChatroomFeatureQuotaSummary conversationEdit;

  Map<String, Object?> toJson() => {
    'membership_status': membershipStatus,
    'is_member': isMember,
    'inspiration': inspiration.toJson(),
    'conversation_edit': conversationEdit.toJson(),
  };
}

/// Authoritative quota returned beside data by an inspiration or batch request.
class ChatroomFeatureQuota extends ChatroomFeatureQuotaSummary {
  const ChatroomFeatureQuota({
    required this.feature,
    required this.membershipStatus,
    required this.isMember,
    required this.consumed,
    required super.scope,
    required super.unlimited,
    required super.limit,
    required super.used,
    required super.remaining,
    required super.resetAtUnixSeconds,
  });

  final String feature;
  final int membershipStatus;
  final bool isMember;
  final int consumed;

  factory ChatroomFeatureQuota.fromJson(Object? value) {
    if (value is! Map ||
        !const {
          'inspiration',
          'conversation_edit',
        }.contains(value['feature']) ||
        value['membership_status'] is! int ||
        !const {0, 1, 2}.contains(value['membership_status']) ||
        value['is_member'] is! bool) {
      throw const FormatException('Invalid operation feature quota');
    }
    final summary = ChatroomFeatureQuotaSummary.fromJson(value);
    return ChatroomFeatureQuota(
      feature: value['feature'] as String,
      membershipStatus: value['membership_status'] as int,
      isMember: value['is_member'] as bool,
      consumed: _nonNegativeInt(value['consumed'], 'consumed'),
      scope: summary.scope,
      unlimited: summary.unlimited,
      limit: summary.limit,
      used: summary.used,
      remaining: summary.remaining,
      resetAtUnixSeconds: summary.resetAtUnixSeconds,
    );
  }

  /// Optional metadata must never turn an already committed operation into an
  /// apparent failure, which could cause a caller to submit it a second time.
  static ChatroomFeatureQuota? tryParse(Object? value) {
    try {
      return ChatroomFeatureQuota.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'feature': feature,
    'membership_status': membershipStatus,
    'is_member': isMember,
    'consumed': consumed,
  };
}

class ChatroomFeatureQuotaException extends ApiException {
  ChatroomFeatureQuotaException({
    super.message = 'Feature quota exhausted',
    this.quota,
  }) : super(code: 2030, kind: ApiExceptionKind.business);

  final ChatroomFeatureQuota? quota;
}

int _nonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw FormatException('Invalid feature quota $field');
  }
  return value;
}

int? _nullableNonNegativeInt(Object? value, String field) {
  if (value == null) return null;
  return _nonNegativeInt(value, field);
}

int? _nullableInt(Object? value, String field) {
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Invalid feature quota $field');
  }
  return value;
}

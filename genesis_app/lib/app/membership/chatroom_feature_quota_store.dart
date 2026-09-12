import 'package:flutter/foundation.dart';

import '../../network/chatroom/chatroom_feature_quota_models.dart';
import '../../network/http_transport.dart';

typedef ChatroomFeatureQuotaLoader =
    Future<ChatroomFeatureQuotas> Function({
      NetworkCancellationToken? cancellationToken,
    });

/// Account-scoped server snapshots. Reading state never starts a request, and
/// completed snapshots are not used to bypass a later explicit [fetch].
class ChatroomFeatureQuotaStore extends ChangeNotifier {
  ChatroomFeatureQuotaStore({required this.loadQuotas, this.refreshMembership});

  final ChatroomFeatureQuotaLoader loadQuotas;
  final Future<void> Function()? refreshMembership;

  final Map<String, ChatroomFeatureQuotaSummary> _quotas = {};
  final Map<String, (int, bool)> _quotaMemberships = {};
  final Map<String, int> _quotaRevisions = {};
  bool? _isMember;
  int? _membershipStatus;
  int _membershipRevision = 0;
  int _session = 0;
  bool _hasRequested = false;
  bool _disposed = false;
  Object? _lastError;
  Future<ChatroomFeatureQuotas>? _inFlight;
  Future<void>? _membershipRefresh;
  Future<void>? _membershipReconciliation;
  NetworkCancellationToken? _cancellationToken;

  bool? get isMember => _isMember;
  bool get hasRequested => _hasRequested;
  bool get isLoading => _inFlight != null;
  Object? get lastError => _lastError;

  ChatroomFeatureQuotaSummary? quotaFor(String feature) => _quotas[feature];

  Future<ChatroomFeatureQuotas> fetch() {
    if (_disposed) {
      return Future.error(const NetworkRequestCancelledException());
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final session = _session;
    final revisions = Map<String, int>.of(_quotaRevisions);
    final membershipRevision = _membershipRevision;
    final cancellationToken = NetworkCancellationToken();
    _cancellationToken = cancellationToken;
    _hasRequested = true;
    _lastError = null;
    late final Future<ChatroomFeatureQuotas> future;
    future = Future.sync(() => loadQuotas(cancellationToken: cancellationToken))
        .then((response) {
          if (_disposed || session != _session) {
            throw const NetworkRequestCancelledException();
          }
          for (final entry in {
            'inspiration': response.inspiration,
            'conversation_edit': response.conversationEdit,
          }.entries) {
            // An operation completed while this GET was running. Its returned
            // balance is newer than the GET's snapshot, independently per feature.
            if (revisions[entry.key] == _quotaRevisions[entry.key]) {
              _quotas[entry.key] = entry.value;
              _quotaMemberships[entry.key] = (
                response.membershipStatus,
                response.isMember,
              );
            }
          }
          if (membershipRevision == _membershipRevision) {
            _isMember = response.isMember;
            _membershipStatus = response.membershipStatus;
          }
          _lastError = null;
          return ChatroomFeatureQuotas(
            membershipStatus: _membershipStatus ?? response.membershipStatus,
            isMember: _isMember ?? response.isMember,
            inspiration: _quotas['inspiration']!,
            conversationEdit: _quotas['conversation_edit']!,
          );
        })
        .catchError((Object error) {
          if (!_disposed && session == _session) _lastError = error;
          throw error;
        })
        .whenComplete(() {
          if (!_disposed &&
              session == _session &&
              identical(_inFlight, future)) {
            _inFlight = null;
            _cancellationToken = null;
            notifyListeners();
          }
        });
    _inFlight = future;
    notifyListeners();
    return future;
  }

  /// Called only with the result of MembershipAccessStore.checkVip. This does
  /// not synthesize unlimited quotas or make an otherwise unused quota query.
  void confirmMembership(bool isMember) {
    if (_disposed || _isMember == isMember) return;
    _isMember = isMember;
    _membershipStatus = isMember ? 1 : 0;
    _membershipRevision += 1;
    notifyListeners();
  }

  /// Captured when a real operation starts, before awaiting its HTTP response.
  /// Cached inspiration reads must never call this observer.
  void Function(ChatroomFeatureQuota quota) beginOperation() {
    final session = _session;
    return (quota) {
      if (_disposed || session != _session) return;
      if (quota.feature != 'inspiration' &&
          quota.feature != 'conversation_edit') {
        return;
      }
      final previous = _quotas[quota.feature];
      final sameAllocation =
          previous != null &&
          _quotaMemberships[quota.feature] ==
              (quota.membershipStatus, quota.isMember) &&
          previous.scope == quota.scope &&
          previous.unlimited == quota.unlimited &&
          previous.limit == quota.limit &&
          previous.resetAtUnixSeconds == quota.resetAtUnixSeconds;
      // Parallel saves may complete out of order. Within one allocation used
      // is cumulative; a lower value is an older response, regardless of which
      // request started first. GET snapshots and new allocations may reset it.
      if (sameAllocation && quota.used < previous.used) return;
      final membershipChanged =
          _isMember != null && _isMember != quota.isMember;
      _quotas[quota.feature] = quota;
      _quotaMemberships[quota.feature] = (
        quota.membershipStatus,
        quota.isMember,
      );
      _quotaRevisions.update(
        quota.feature,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      _isMember = quota.isMember;
      _membershipStatus = quota.membershipStatus;
      _membershipRevision += 1;
      _lastError = null;
      notifyListeners();
      if (membershipChanged) _reconcileMembership();
    };
  }

  void _reconcileMembership() {
    final refresh = refreshMembership;
    if (refresh == null || _membershipReconciliation != null) return;
    late final Future<void> future;
    future = Future.sync(refresh)
        .catchError((Object _) {
          // The operation quota remains authoritative if wallet refresh fails.
        })
        .whenComplete(() {
          if (identical(_membershipReconciliation, future)) {
            _membershipReconciliation = null;
          }
        });
    _membershipReconciliation = future;
  }

  /// Membership purchases/restores refresh only an already-used quota store.
  /// A request that started before the entitlement change cannot satisfy this
  /// refresh. Errors remain observable and a later user action can retry.
  Future<void> refreshAfterMembershipChanged() {
    if (_disposed || !_hasRequested) return Future.value();
    final pending = _membershipRefresh;
    if (pending != null) return pending;
    final session = _session;
    final earlierRequest = _inFlight;
    late final Future<void> future;
    future =
        () async {
          if (earlierRequest != null) {
            try {
              await earlierRequest;
            } catch (_) {
              // Still make the request required after the entitlement change.
            }
          }
          if (_disposed || session != _session) return;
          try {
            await fetch();
          } catch (_) {
            // fetch keeps the last good counts and publishes the refresh failure.
          }
        }().whenComplete(() {
          if (identical(_membershipRefresh, future)) _membershipRefresh = null;
        });
    _membershipRefresh = future;
    return future;
  }

  void resetForSession() {
    if (_disposed) return;
    _session += 1;
    _cancellationToken?.cancel();
    _cancellationToken = null;
    _inFlight = null;
    _membershipRefresh = null;
    _membershipReconciliation = null;
    _quotas.clear();
    _quotaMemberships.clear();
    _quotaRevisions.clear();
    _isMember = null;
    _membershipStatus = null;
    _membershipRevision = 0;
    _hasRequested = false;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session += 1;
    _cancellationToken?.cancel();
    _inFlight = null;
    _membershipRefresh = null;
    _membershipReconciliation = null;
    super.dispose();
  }
}

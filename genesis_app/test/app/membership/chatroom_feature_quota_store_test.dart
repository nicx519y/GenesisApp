import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/chatroom_feature_quota_store.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_feature_quota_models.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

ChatroomFeatureQuotaSummary _summary(int? remaining) =>
    ChatroomFeatureQuotaSummary(
      scope: remaining == null
          ? ChatroomFeatureQuotaScope.memberUnlimited
          : ChatroomFeatureQuotaScope.trialLifetime,
      unlimited: remaining == null,
      limit: remaining == null ? null : 5,
      used: remaining == null ? 0 : 5 - remaining,
      remaining: remaining,
      resetAtUnixSeconds: null,
    );

ChatroomFeatureQuotas _snapshot({
  int? inspiration = 3,
  int? edit = 2,
  bool isMember = false,
}) => ChatroomFeatureQuotas(
  membershipStatus: isMember ? 1 : 0,
  isMember: isMember,
  inspiration: _summary(inspiration),
  conversationEdit: _summary(edit),
);

ChatroomFeatureQuota _operation({
  String feature = 'conversation_edit',
  int? remaining = 1,
  bool isMember = false,
  int consumed = 1,
  ChatroomFeatureQuotaSummary? summary,
}) => ChatroomFeatureQuota.fromJson({
  ...(summary ?? _summary(remaining)).toJson(),
  'feature': feature,
  'membership_status': isMember ? 1 : 0,
  'is_member': isMember,
  'consumed': consumed,
});

void main() {
  test(
    'state reads and local VIP confirmation do not request quotas',
    () async {
      var requests = 0;
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) async {
          requests += 1;
          return _snapshot();
        },
      );
      addTearDown(store.dispose);
      expect(store.isMember, isNull);
      expect(store.quotaFor('inspiration'), isNull);
      store.confirmMembership(true);
      await store.refreshAfterMembershipChanged();
      expect(store.isMember, isTrue);
      expect(store.quotaFor('conversation_edit'), isNull);
      expect(store.hasRequested, isFalse);
      expect(requests, 0);
    },
  );

  test('concurrent lookups share HTTP but later actions query again', () async {
    var requests = 0;
    var response = Completer<ChatroomFeatureQuotas>();
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) {
        requests += 1;
        return response.future;
      },
    );
    addTearDown(store.dispose);
    final first = store.fetch();
    final second = store.fetch();
    expect(identical(first, second), isTrue);
    expect(store.isLoading, isTrue);
    expect(requests, 1);
    response.complete(_snapshot());
    await first;
    expect(store.isLoading, isFalse);
    response = Completer<ChatroomFeatureQuotas>();
    final later = store.fetch();
    expect(requests, 2);
    response.complete(_snapshot(edit: 1));
    await later;
    expect(store.quotaFor('conversation_edit')?.remaining, 1);
  });

  test(
    'failed lookup keeps the last successful counts and can retry',
    () async {
      Object? failure;
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) async {
          if (failure != null) throw failure;
          return _snapshot();
        },
      );
      addTearDown(store.dispose);
      await store.fetch();
      failure = StateError('temporarily offline');
      await expectLater(store.fetch(), throwsStateError);
      expect(store.lastError, same(failure));
      expect(store.quotaFor('conversation_edit')?.remaining, 2);
      expect(store.quotaFor('inspiration')?.remaining, 3);
      failure = null;
      await store.fetch();
      expect(store.lastError, isNull);
    },
  );

  test(
    'late GET cannot replace newer operation quota for that feature',
    () async {
      final response = Completer<ChatroomFeatureQuotas>();
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) => response.future,
      );
      addTearDown(store.dispose);
      final request = store.fetch();
      store.beginOperation()(_operation(remaining: 0));
      response.complete(_snapshot(edit: 2));
      final merged = await request;
      expect(merged.conversationEdit.remaining, 0);
      expect(merged.inspiration.remaining, 3);
      expect(store.quotaFor('conversation_edit')?.remaining, 0);
      expect(store.quotaFor('inspiration')?.remaining, 3);
    },
  );

  test('last successful use is the returned count without local deduction', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    final receive = store.beginOperation();
    receive(_operation(remaining: 0, consumed: 1));
    expect(store.quotaFor('conversation_edit')?.remaining, 0);
    // A returned reuse with consumed=0 is another authoritative snapshot.
    receive(_operation(feature: 'inspiration', remaining: 2, consumed: 0));
    expect(store.quotaFor('inspiration')?.remaining, 2);
    expect(store.quotaFor('conversation_edit')?.remaining, 0);
    expect(store.hasRequested, isFalse);
  });

  test('out-of-order saves cannot restore a spent use or stale membership', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    final earlierSave = store.beginOperation();
    final laterSave = store.beginOperation();
    final exhausted = _operation(remaining: 0);
    laterSave(exhausted);
    store.confirmMembership(true);
    var notifications = 0;
    store.addListener(() => notifications += 1);
    earlierSave(_operation(remaining: 1));
    expect(store.quotaFor('conversation_edit'), same(exhausted));
    expect(store.isMember, isTrue);
    expect(notifications, 0);
  });

  test('used counts determine order independently of request start order', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    final earlierSave = store.beginOperation();
    final laterSave = store.beginOperation();
    laterSave(_operation(remaining: 1));
    earlierSave(_operation(remaining: 0));
    expect(store.quotaFor('conversation_edit')?.remaining, 0);
  });

  test(
    'ignored old save does not prevent in-flight GET from correcting used',
    () async {
      final response = Completer<ChatroomFeatureQuotas>();
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) => response.future,
      );
      addTearDown(store.dispose);
      final earlierSave = store.beginOperation();
      store.beginOperation()(_operation(remaining: 0));
      final request = store.fetch();
      earlierSave(_operation(remaining: 1));
      response.complete(_snapshot(edit: 3));
      final corrected = await request;
      expect(corrected.conversationEdit.remaining, 3);
      expect(store.quotaFor('conversation_edit')?.used, 2);
    },
  );

  test('a membership change permits its independent lower usage count', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    store.beginOperation()(_operation(remaining: 2));
    final memberQuota = _operation(remaining: null, isMember: true);
    store.beginOperation()(memberQuota);
    expect(store.quotaFor('conversation_edit'), same(memberQuota));
    expect(store.isMember, isTrue);
    // After membership ends, the separate trial allocation is restored.
    store.beginOperation()(_operation(remaining: 2));
    expect(store.quotaFor('conversation_edit')?.remaining, 2);
    expect(store.isMember, isFalse);
  });

  test('a new daily quota window permits its reset usage count', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    ChatroomFeatureQuota daily(int used, int resetAt) => _operation(
      isMember: true,
      summary: ChatroomFeatureQuotaSummary(
        scope: ChatroomFeatureQuotaScope.memberDaily,
        unlimited: false,
        limit: 5,
        used: used,
        remaining: 5 - used,
        resetAtUnixSeconds: resetAt,
      ),
    );
    store.beginOperation()(daily(5, 1800000000));
    store.beginOperation()(daily(4, 1800000000));
    expect(store.quotaFor('conversation_edit')?.used, 5);
    store.beginOperation()(daily(1, 1800086400));
    expect(store.quotaFor('conversation_edit')?.used, 1);
    expect(store.quotaFor('conversation_edit')?.remaining, 4);
  });

  test('a changed quota allocation permits its lower usage count', () {
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) async => _snapshot(),
    );
    addTearDown(store.dispose);
    store.beginOperation()(_operation(remaining: 0));
    final changedAllocation = _operation(
      summary: const ChatroomFeatureQuotaSummary(
        scope: ChatroomFeatureQuotaScope.trialLifetime,
        unlimited: false,
        limit: 10,
        used: 1,
        remaining: 9,
        resetAtUnixSeconds: null,
      ),
    );
    store.beginOperation()(changedAllocation);
    expect(store.quotaFor('conversation_edit'), same(changedAllocation));
  });

  test('new unlimited operation also supersedes late GET membership', () async {
    final response = Completer<ChatroomFeatureQuotas>();
    final store = ChatroomFeatureQuotaStore(
      loadQuotas: ({cancellationToken}) => response.future,
    );
    addTearDown(store.dispose);
    final request = store.fetch();
    store.beginOperation()(_operation(remaining: null, isMember: true));
    response.complete(_snapshot());
    final merged = await request;
    expect(store.isMember, isTrue);
    expect(merged.isMember, isTrue);
    expect(merged.conversationEdit.unlimited, isTrue);
    expect(merged.conversationEdit.remaining, isNull);
  });

  test(
    'account reset cancels GET and ignores old HTTP operation callbacks',
    () async {
      var response = Completer<ChatroomFeatureQuotas>();
      final tokens = <NetworkCancellationToken>[];
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) {
          tokens.add(cancellationToken!);
          return response.future;
        },
      );
      addTearDown(store.dispose);
      final firstResponse = response;
      final oldRequest = store.fetch();
      final cancelled = expectLater(
        oldRequest,
        throwsA(isA<NetworkRequestCancelledException>()),
      );
      final oldOperation = store.beginOperation();
      store.resetForSession();
      expect(tokens.first.isCancelled, isTrue);
      expect(store.isMember, isNull);
      expect(store.hasRequested, isFalse);
      oldOperation(_operation(remaining: 0));
      expect(store.quotaFor('conversation_edit'), isNull);
      response = Completer<ChatroomFeatureQuotas>();
      final newRequest = store.fetch();
      firstResponse.complete(_snapshot(edit: 0));
      await cancelled;
      expect(store.isLoading, isTrue);
      expect(store.lastError, isNull);
      response.complete(_snapshot(edit: 4));
      await newRequest;
      expect(store.quotaFor('conversation_edit')?.remaining, 4);
    },
  );

  test(
    'disposal cancels pending fetch without publishing its response',
    () async {
      final response = Completer<ChatroomFeatureQuotas>();
      NetworkCancellationToken? token;
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) {
          token = cancellationToken;
          return response.future;
        },
      );
      final request = store.fetch();
      final cancelled = expectLater(
        request,
        throwsA(isA<NetworkRequestCancelledException>()),
      );
      store.dispose();
      expect(token?.isCancelled, isTrue);
      response.complete(_snapshot());
      await cancelled;
    },
  );

  test(
    'entitlement refresh waits for old GET and requests a fresh snapshot',
    () async {
      final responses = <Completer<ChatroomFeatureQuotas>>[];
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) {
          final response = Completer<ChatroomFeatureQuotas>();
          responses.add(response);
          return response.future;
        },
      );
      addTearDown(store.dispose);
      final oldRequest = store.fetch();
      store.confirmMembership(true);
      final refresh = store.refreshAfterMembershipChanged();
      expect(identical(refresh, store.refreshAfterMembershipChanged()), isTrue);
      expect(responses, hasLength(1));
      responses[0].complete(_snapshot());
      final oldResult = await oldRequest;
      expect(oldResult.isMember, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(responses, hasLength(2));
      responses[1].complete(
        _snapshot(inspiration: null, edit: null, isMember: true),
      );
      await refresh;
      expect(store.isMember, isTrue);
      expect(store.quotaFor('inspiration')?.remaining, isNull);
      expect(store.quotaFor('conversation_edit')?.unlimited, isTrue);
    },
  );

  test(
    'server membership mismatch refreshes wallet once while pending',
    () async {
      final walletResponse = Completer<void>();
      var walletRefreshes = 0;
      var quotaRequests = 0;
      final store = ChatroomFeatureQuotaStore(
        loadQuotas: ({cancellationToken}) async {
          quotaRequests += 1;
          return _snapshot();
        },
        refreshMembership: () {
          walletRefreshes += 1;
          return walletResponse.future;
        },
      );
      addTearDown(store.dispose);
      store.confirmMembership(true);
      store.beginOperation()(_operation(remaining: 0));
      expect(store.isMember, isFalse);
      expect(walletRefreshes, 1);
      store.confirmMembership(true);
      store.beginOperation()(_operation(feature: 'inspiration', remaining: 0));
      expect(walletRefreshes, 1);
      expect(quotaRequests, 0);
      walletResponse.complete();
      await walletResponse.future;
    },
  );
}

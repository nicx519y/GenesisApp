import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_store.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CreateOriginDraft namedDraft(String name) => CreateOriginDraft.empty()
      .copyWith(basics: BasicsDraft(originName: name), basicsSaved: true);

  test(
    'create drafts and pending creation are isolated by login UID',
    () async {
      final session = MemoryUserSessionStore();
      await session.saveUid('account_a');
      final repositoryA = CreateOriginDraftRepository(sessionStore: session);
      await repositoryA.saveFinalDraft(namedDraft('Private A'));
      await OriginPendingSubmissionStore.saveCreating(
        'origin_a',
        sessionStore: session,
      );

      await session.saveUid('account_b');
      final repositoryB = CreateOriginDraftRepository(sessionStore: session);
      expect((await repositoryB.loadDraft()).basics.originName, isEmpty);
      expect((await repositoryB.loadSummaryDraft()).basics.originName, isEmpty);
      expect(
        await OriginPendingSubmissionStore.loadCreating(sessionStore: session),
        isNull,
      );
      await repositoryB.saveFinalDraft(namedDraft('Private B'));
      await OriginPendingSubmissionStore.saveCreating(
        'origin_b',
        sessionStore: session,
      );

      await session.saveUid('account_a');
      expect((await repositoryA.loadDraft()).basics.originName, 'Private A');
      expect(
        (await repositoryA.loadSummaryDraft()).basics.originName,
        'Private A',
      );
      expect(
        (await OriginPendingSubmissionStore.loadCreating(
          sessionStore: session,
        ))?.originId,
        'origin_a',
      );
      await CreateOriginDraftStore.clear(sessionStore: session);
      await OriginPendingSubmissionStore.clearCreating(sessionStore: session);

      await session.saveUid('account_b');
      expect((await repositoryB.loadDraft()).basics.originName, 'Private B');
      expect(
        (await OriginPendingSubmissionStore.loadCreating(
          sessionStore: session,
        ))?.originId,
        'origin_b',
      );
    },
  );

  test(
    'an open editor keeps saving to its original owner after a switch',
    () async {
      final session = MemoryUserSessionStore();
      await session.saveUid('account_a');
      final editor = CreateOriginDraftRepository(sessionStore: session);
      await editor.loadDraft();

      await session.saveUid('account_b');
      await editor.saveTempDraft(namedDraft('A after switch'));

      expect(
        (await CreateOriginDraftStore.load(
          ownerUid: 'account_a',
        )).basics.originName,
        'A after switch',
      );
      expect(
        (await CreateOriginDraftStore.load(
          ownerUid: 'account_b',
        )).basics.originName,
        isEmpty,
      );
    },
  );

  test('legacy unowned draft stays with anonymous owner', () async {
    final legacy = namedDraft('Legacy unowned');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'create_origin_draft_v1',
      jsonEncode(legacy.toJson()),
    );
    final session = MemoryUserSessionStore();
    await session.saveUid('account_a');
    expect(
      (await CreateOriginDraftStore.load(
        sessionStore: session,
      )).basics.originName,
      isEmpty,
    );
    await session.clearUid();
    expect(
      (await CreateOriginDraftStore.load(
        sessionStore: session,
      )).basics.originName,
      legacy.basics.originName,
    );
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/network/models/personalization.dart';
import '../../support/personalization_fixtures.dart';

void main() {
  test(
    'disabled form skips reads across refresh and session changes',
    () async {
      var calls = 0;
      final store = PersonalizationStore(
        readLoginUid: () async => 'user',
        load: () async {
          calls++;
          return personalizationData();
        },
        save: (_) async => throw UnimplementedError(),
      );
      addTearDown(store.dispose);
      store.setEnabled(false);
      expect(await store.start(), isNull);
      expect(await store.refresh(), isNull);
      store.resetForSession();
      expect(calls, 0);
      expect(store.isStarted, isFalse);
      expect(store.blocksOtherPrompts.value, isFalse);

      store.setEnabled(true);
      await store.start();
      expect(calls, 1);
      expect(store.blocksOtherPrompts.value, isTrue);
      store.setEnabled(false);
      store.resetForSession();
      await store.refresh();
      expect(calls, 1);
      expect(store.state.value.data, isNull);
      expect(store.blocksOtherPrompts.value, isFalse);
    },
  );

  test('disabling form discards an in-flight profile response', () async {
    final response = Completer<PersonalizationData>();
    final entered = Completer<void>();
    final store = PersonalizationStore(
      readLoginUid: () async => null,
      load: () {
        entered.complete();
        return response.future;
      },
      save: (_) async => throw UnimplementedError(),
    );
    addTearDown(store.dispose);
    final loading = store.start();
    await entered.future;
    store.setEnabled(false);
    response.complete(personalizationData());
    expect(await loading, isNull);
    expect(store.state.value.data, isNull);
    expect(store.blocksOtherPrompts.value, isFalse);
  });

  test(
    'start coalesces and only server save completes the current identity',
    () async {
      final response = Completer<PersonalizationData>();
      var calls = 0;
      var failSave = true;
      final store = PersonalizationStore(
        readLoginUid: () async => null,
        load: () {
          calls++;
          return response.future;
        },
        save: (profile) async {
          if (failSave) throw StateError('offline');
          return PersonalizationProfile(
            gender: profile.gender,
            age: profile.age,
            completed: true,
          );
        },
      );
      addTearDown(store.dispose);
      final first = store.start();
      final second = store.start();
      response.complete(personalizationData());
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(store.blocksOtherPrompts.value, isTrue);
      const profile = PersonalizationProfile(gender: 'g4', age: 'a6');
      await expectLater(store.submit(profile), throwsStateError);
      expect(store.state.value.data!.profile.completed, isFalse);
      store.beginPresentation();
      failSave = false;
      await store.submit(profile);
      expect(store.state.value.data!.profile.completed, isTrue);
      expect(store.blocksOtherPrompts.value, isTrue);
      store.endPresentation();
      expect(store.blocksOtherPrompts.value, isFalse);
    },
  );

  test(
    'failed read stays unknown and retries without assuming completion',
    () async {
      var failed = true;
      final store = PersonalizationStore(
        readLoginUid: () async => 'user',
        load: () async {
          if (failed) throw StateError('offline');
          return personalizationData(completed: true);
        },
        save: (_) async => throw UnimplementedError(),
      );
      addTearDown(store.dispose);
      expect(await store.start(), isNull);
      expect(store.state.value.error, isNotNull);
      expect(store.blocksOtherPrompts.value, isTrue);
      failed = false;
      await store.refresh();
      expect(store.blocksOtherPrompts.value, isFalse);
    },
  );

  test(
    'late guest response cannot overwrite the newly logged in account',
    () async {
      String? uid;
      final guest = Completer<PersonalizationData>();
      final entered = Completer<void>();
      final store = PersonalizationStore(
        readLoginUid: () async => uid,
        load: () {
          if (uid == null) {
            entered.complete();
            return guest.future;
          }
          return Future.value(personalizationData());
        },
        save: (_) async => throw UnimplementedError(),
      );
      addTearDown(store.dispose);
      final pending = store.start();
      await entered.future;
      uid = 'new-user';
      store.resetForSession();
      await store.refresh();
      guest.complete(personalizationData(completed: true));
      await pending;
      expect(store.state.value.uid, 'new-user');
      expect(store.state.value.data!.profile.completed, isFalse);
      expect(store.blocksOtherPrompts.value, isTrue);
    },
  );

  test('save for previous account cannot complete the next account', () async {
    var uid = 'old';
    final saved = Completer<PersonalizationProfile>();
    final entered = Completer<void>();
    final store = PersonalizationStore(
      readLoginUid: () async => uid,
      load: () async => personalizationData(),
      save: (_) {
        entered.complete();
        return saved.future;
      },
    );
    addTearDown(store.dispose);
    await store.start();
    final submit = store.submit(
      const PersonalizationProfile(gender: 'g1', age: 'a2'),
    );
    final rejected = expectLater(submit, throwsStateError);
    await entered.future;
    uid = 'new';
    store.resetForSession();
    await store.refresh();
    saved.complete(
      const PersonalizationProfile(gender: 'g1', age: 'a2', completed: true),
    );
    await rejected;
    expect(store.state.value.uid, 'new');
    expect(store.state.value.data!.profile.completed, isFalse);
  });
}

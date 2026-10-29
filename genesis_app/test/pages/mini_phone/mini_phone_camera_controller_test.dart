import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_controller.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';

const _scope = MiniPhoneCameraScope(
  environment: 'test',
  accountId: 'account-a',
  worldId: 'world-a',
);
const _person = PhonePerson('character-a', 'Character A', '');

void main() {
  late MiniPhoneRequests requests;
  late MiniPhoneCameraController camera;
  var disposed = false;

  setUp(() {
    disposed = false;
    requests = MiniPhoneRequests(() {})..uid = _scope.accountId;
    camera = MiniPhoneCameraController(requests: requests, scope: _scope);
    camera.setPeople([_person]);
  });
  tearDown(() {
    if (!disposed) camera.dispose();
  });

  void prepare() {
    camera.togglePerson(_person);
    camera.setPrompt('  A selected scene  ');
  }

  MiniPhoneCameraResult photo(String suffix) =>
      MiniPhoneCameraResult(imageUrl: 'https://camera.test/$suffix.webp');

  test(
    'requires people, nonblank prompt, identity and an actual adapter',
    () async {
      var calls = 0;
      Future<MiniPhoneCameraResult> adapter(
        MiniPhoneCameraRequest request,
        MiniPhoneCameraCancellation cancellation,
      ) async {
        calls++;
        return photo('real');
      }

      await camera.generate(adapter);
      camera.togglePerson(_person);
      camera.setPrompt('  ');
      await camera.generate(adapter);
      camera.setPrompt('A scene');
      await camera.generate(null);
      requests.uid = null;
      await camera.generate(adapter);
      expect(calls, 0);
      expect(camera.result, isNull);
      expect(camera.phase, MiniPhoneCameraPhase.compose);
    },
  );

  test(
    'sends an immutable snapshot of actual selected PhonePerson objects',
    () async {
      prepare();
      late MiniPhoneCameraRequest input;
      final output = photo('snapshot');
      await camera.generate((request, cancellation) async {
        input = request;
        expect(cancellation.isCancelled, isFalse);
        expect(camera.phase, MiniPhoneCameraPhase.generating);
        return output;
      });
      expect(input.scope, _scope);
      expect(input.participants.single, same(_person));
      expect(() => input.participants.clear(), throwsUnsupportedError);
      expect(input.prompt, 'A selected scene');
      expect(camera.result, same(output));
      expect(camera.result!.photosStatus, MiniPhoneCameraPhotosStatus.none);
      expect(camera.resultRequest, same(input));
      expect(camera.phase, MiniPhoneCameraPhase.result);
    },
  );

  test(
    'uses the full PhonePerson key and never implicitly selects yourself',
    () {
      const otherType = PhonePerson('character-a', 'User A', '', type: 1);
      camera.setPeople([_person, otherType]);
      expect(camera.selectedPeople, isEmpty);
      camera.togglePerson(otherType);
      expect(camera.isSelected(_person), isFalse);
      expect(camera.selectedPeople.single, same(otherType));
      camera.setPeople([_person]);
      expect(camera.selectedPeople, isEmpty);
    },
  );

  test(
    'double tap dispatches once, cancel keeps draft and drops late success',
    () async {
      prepare();
      final output = Completer<MiniPhoneCameraResult>();
      late MiniPhoneCameraCancellation token;
      var calls = 0;
      Future<MiniPhoneCameraResult> adapter(
        MiniPhoneCameraRequest request,
        MiniPhoneCameraCancellation cancellation,
      ) {
        calls++;
        token = cancellation;
        return output.future;
      }

      final task = camera.generate(adapter);
      await camera.generate(adapter);
      camera.cancel();
      await token.whenCancelled;
      expect(token.isCancelled, isTrue);
      expect(token.throwIfCancelled, throwsA(isA<MiniPhoneCameraCancelled>()));
      expect(camera.prompt, '  A selected scene  ');
      expect(camera.selectedPeople, [_person]);
      output.complete(photo('cancelled'));
      await task;
      expect(calls, 1);
      expect(camera.result, isNull);
      expect(camera.phase, MiniPhoneCameraPhase.compose);
    },
  );

  test(
    'phone close/reopen retains draft and cancels the old request',
    () async {
      prepare();
      final output = Completer<MiniPhoneCameraResult>();
      late MiniPhoneCameraCancellation token;
      final task = camera.generate((request, cancellation) {
        token = cancellation;
        return output.future;
      });
      camera.close();
      expect(token.isCancelled, isTrue);
      expect(camera.canGenerate, isFalse);
      camera.open();
      expect(camera.prompt, '  A selected scene  ');
      expect(camera.selectedPeople, [_person]);
      expect(camera.canGenerate, isTrue);
      output.complete(photo('closed'));
      await task;
      expect(camera.result, isNull);
      expect(camera.phase, MiniPhoneCameraPhase.compose);
    },
  );

  test(
    'closing a displayed result removes it while keeping its editable draft',
    () async {
      prepare();
      await camera.generate((_, _) async => photo('shown'));
      camera.close();
      camera.open();
      expect(camera.result, isNull);
      expect(camera.resultRequest, isNull);
      expect(camera.prompt.trim(), 'A selected scene');
      expect(camera.selectedPeople, [_person]);
    },
  );

  for (final scope in [
    const MiniPhoneCameraScope(
      environment: 'other',
      accountId: 'account-a',
      worldId: 'world-a',
    ),
    const MiniPhoneCameraScope(
      environment: 'test',
      accountId: 'account-b',
      worldId: 'world-a',
    ),
    const MiniPhoneCameraScope(
      environment: 'test',
      accountId: 'account-a',
      worldId: 'world-b',
    ),
  ]) {
    test(
      'scope change clears draft and rejects late success: ${scope.environment}/${scope.accountId}/${scope.worldId}',
      () async {
        prepare();
        final oldOutput = Completer<MiniPhoneCameraResult>();
        final oldTask = camera.generate((_, _) => oldOutput.future);
        camera.bindScope(scope);
        requests.uid = scope.accountId;
        expect(camera.prompt, isEmpty);
        expect(camera.selectedPeople, isEmpty);
        expect(camera.result, isNull);
        camera.setPeople([_person]);
        prepare();
        final current = photo('current');
        await camera.generate((_, _) async => current);
        oldOutput.complete(photo('old-scope'));
        await oldTask;
        expect(camera.result, same(current));
        expect(camera.hasFailure, isFalse);
      },
    );
  }

  for (final fails in [false, true]) {
    test(
      'shared account generation discards late ${fails ? 'error' : 'success'} without a UI rebuild',
      () async {
        prepare();
        final output = Completer<MiniPhoneCameraResult>();
        late MiniPhoneCameraCancellation token;
        final task = camera.generate((_, cancellation) {
          token = cancellation;
          return output.future;
        });
        requests.reset();
        requests.uid = 'account-a';
        expect(token.isCancelled, isTrue);
        if (fails) {
          output.completeError(StateError('Old account'));
        } else {
          output.complete(photo('old-generation'));
        }
        await task;
        expect(camera.result, isNull);
        expect(camera.hasFailure, isFalse);
        camera.bindScope(_scope);
        expect(camera.prompt, isEmpty);
        expect(camera.selectedPeople, isEmpty);
        expect(camera.phase, MiniPhoneCameraPhase.compose);
      },
    );
  }

  test('old cancelled error cannot replace a newer successful photo', () async {
    prepare();
    final oldOutput = Completer<MiniPhoneCameraResult>();
    final oldTask = camera.generate((_, _) => oldOutput.future);
    camera.cancel();
    final current = photo('newest');
    await camera.generate((_, _) async => current);
    oldOutput.completeError(StateError('Old request failure'));
    await oldTask;
    expect(camera.result, same(current));
    expect(camera.hasFailure, isFalse);
  });

  test('failure preserves draft for an explicit retry', () async {
    prepare();
    await camera.generate((_, _) async => throw StateError('Rejected'));
    expect(camera.hasFailure, isTrue);
    expect(camera.phase, MiniPhoneCameraPhase.compose);
    expect(camera.prompt.trim(), 'A selected scene');
    expect(camera.selectedPeople, [_person]);
    await camera.generate((_, _) async => photo('retry'));
    expect(camera.hasFailure, isFalse);
    expect(camera.phase, MiniPhoneCameraPhase.result);
    camera.takeAnother();
    expect(camera.result, isNull);
    expect(camera.prompt.trim(), 'A selected scene');
    expect(camera.selectedPeople, [_person]);
  });

  for (final fails in [false, true]) {
    test(
      'dispose drops late ${fails ? 'error' : 'success'} without notifying',
      () async {
        prepare();
        var notifications = 0;
        camera.addListener(() {
          notifications++;
        });
        final output = Completer<MiniPhoneCameraResult>();
        final task = camera.generate((_, _) => output.future);
        camera.dispose();
        disposed = true;
        final before = notifications;
        if (fails) {
          output.completeError(StateError('Disposed'));
        } else {
          output.complete(photo('disposed'));
        }
        await task;
        expect(camera.result, isNull);
        expect(notifications, before);
        expect(camera.canGenerate, isFalse);
      },
    );
  }

  test(
    'old page disposal cannot close its replacement using the same controller',
    () async {
      prepare();
      final oldOwner = camera.open();
      final currentOwner = camera.open();
      final output = Completer<MiniPhoneCameraResult>();
      final task = camera.generate((_, _) => output.future);
      camera.close(owner: oldOwner);
      expect(camera.phase, MiniPhoneCameraPhase.generating);
      final current = photo('new-owner');
      output.complete(current);
      await task;
      expect(camera.result, same(current));
      camera.close(owner: currentOwner);
      expect(camera.result, isNull);
      expect(camera.prompt.trim(), 'A selected scene');
    },
  );

  test(
    'reentrant cancel during notification prevents adapter dispatch',
    () async {
      prepare();
      camera.addListener(() {
        if (camera.phase == MiniPhoneCameraPhase.generating) camera.cancel();
      });
      var calls = 0;
      await camera.generate((_, _) async {
        calls++;
        return photo('unused');
      });
      expect(calls, 0);
      expect(camera.result, isNull);
    },
  );

  test(
    'only caller-confirmed sync state is shown and stale updates are ignored',
    () async {
      prepare();
      final first = photo('first');
      await camera.generate((_, _) async => first);
      camera.updatePhotosStatus(first, MiniPhoneCameraPhotosStatus.syncing);
      camera.updatePhotosStatus(first, MiniPhoneCameraPhotosStatus.saved);
      expect(camera.result!.photosStatus, MiniPhoneCameraPhotosStatus.saved);
      camera.takeAnother();
      final second = photo('second');
      await camera.generate((_, _) async => second);
      camera.updatePhotosStatus(first, MiniPhoneCameraPhotosStatus.failed);
      expect(camera.result, same(second));
    },
  );

  test(
    'build-time binding may suppress notifications but still clears old data',
    () {
      prepare();
      var notifications = 0;
      camera.addListener(() {
        notifications++;
      });
      requests.reset();
      camera.bindScope(_scope, notify: false);
      expect(camera.prompt, isEmpty);
      expect(camera.selectedPeople, isEmpty);
      expect(notifications, 0);
    },
  );

  test('result refuses bundled samples and fabricated local image paths', () {
    for (final value in [
      '',
      'assets/sample.webp',
      'file:///sample.webp',
      'data:image/png;base64,AA==',
    ]) {
      expect(() => MiniPhoneCameraResult(imageUrl: value), throwsArgumentError);
    }
  });
}

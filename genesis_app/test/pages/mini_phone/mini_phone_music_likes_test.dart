import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_likes.dart';

const file = '001.mp3';
MusicTrack track(bool liked, {int count = 10, String name = file}) =>
    MusicTrack(
      file: name,
      audioUrl: 'https://audio.test/$name',
      sourceWorldoId: 'o_test',
      sourceWorldoName: 'Worldo',
      artist: 'Artist',
      title: 'Track',
      coverUrl: 'https://covers.test/cover.jpg',
      likeCount: count,
      isLiked: liked,
    );
Future<void> seed(
  MiniPhoneMusicLikes likes,
  bool liked, {
  int count = 10,
}) async {
  likes.applyCatalog([track(liked, count: count)], likes.beginSnapshot());
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MiniPhoneMusicLikes likes;
  setUp(() => likes = MiniPhoneMusicLikes());
  tearDown(() => likes.dispose());

  test(
    'loads server likes and updates synchronously before a submission completes',
    () async {
      await seed(likes, true);
      final gate = Completer<void>();
      final pending = likes.toggle(file, (liked) {
        expect(liked, isFalse);
        return gate.future;
      });
      expect(likes.isLiked(file), isFalse);
      expect(likes.likeCount(file), 9);
      await flush();
      gate.complete();
      await pending;
      expect(likes.isLiked(file), isFalse);
    },
  );

  for (final initial in [false, true]) {
    test(
      'failed ${initial ? 'unlike' : 'like'} rolls back and preserves server error',
      () async {
        await seed(likes, initial);
        final gate = Completer<void>();
        final pending = likes.toggle(file, (_) => gate.future);
        expect(likes.isLiked(file), !initial);
        expect(likes.likeCount(file), initial ? 9 : 11);
        final error = ApiException(message: '数据库繁忙', code: 5001);
        final assertion = expectLater(pending, throwsA(same(error)));
        gate.completeError(error);
        await assertion;
        expect(likes.isLiked(file), initial);
        expect(likes.likeCount(file), 10);
      },
    );
  }

  test(
    'a delayed status response cannot overwrite an optimistic tap',
    () async {
      await seed(likes, false);
      final snapshot = likes.beginSnapshot();
      final write = Completer<void>();
      final saving = likes.toggle(file, (_) => write.future);
      likes.applyCatalog([track(false, count: 100)], snapshot);
      expect(likes.isLiked(file), isTrue);
      expect(likes.likeCount(file), 11);
      final duringWrite = likes.beginSnapshot();
      likes.applyCatalog([track(false, count: 200)], duringWrite);
      expect(likes.likeCount(file), 11);
      write.complete();
      await saving;
      expect(likes.isLiked(file), isTrue);
    },
  );

  test(
    'rapid taps submit in order and latest failure restores last confirmed state',
    () async {
      await seed(likes, false);
      final gates = [Completer<void>(), Completer<void>()];
      final requests = <bool>[];
      Future<void> submit(bool target) {
        requests.add(target);
        return gates[requests.length - 1].future;
      }

      final first = likes.toggle(file, submit);
      final second = likes.toggle(file, submit);
      expect(likes.isLiked(file), isFalse);
      await flush();
      expect(requests, [true]);
      gates[0].complete();
      await first;
      await flush();
      expect(requests, [true, false]);
      final assertion = expectLater(second, throwsStateError);
      gates[1].completeError(StateError('offline'));
      await assertion;
      expect(likes.isLiked(file), isTrue);
      expect(likes.likeCount(file), 11);
    },
  );

  test(
    'old failure cannot roll back a newer tap, and the queue continues',
    () async {
      await seed(likes, false);
      final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
      var calls = 0;
      Future<void> submit(bool _) => gates[calls++].future;
      final first = likes.toggle(file, submit);
      final firstError = expectLater(first, throwsStateError);
      final second = likes.toggle(file, submit);
      final third = likes.toggle(file, submit);
      gates[0].completeError(StateError('offline'));
      await firstError;
      expect(likes.isLiked(file), isTrue);
      gates[1].complete();
      await second;
      expect(likes.isLiked(file), isTrue);
      gates[2].complete();
      await third;
      expect(likes.isLiked(file), isTrue);
      expect(likes.likeCount(file), 11);
    },
  );

  test(
    'failure for a previous song does not affect the newly selected song',
    () async {
      final gate = Completer<void>();
      final first = likes.toggle(file, (_) => gate.future);
      final assertion = expectLater(first, throwsStateError);
      await likes.toggle('002.mp3', (_) async {});
      gate.completeError(StateError('offline'));
      await assertion;
      expect(likes.isLiked(file), isFalse);
      expect(likes.isLiked('002.mp3'), isTrue);
    },
  );

  test(
    'newer snapshots win and writes invalidate even completed reads',
    () async {
      await seed(likes, false);
      final older = likes.beginSnapshot();
      final newer = likes.beginSnapshot();
      likes.applyCatalog([track(true, count: 20)], newer);
      likes.applyCatalog([track(false, count: 100)], older);
      expect(likes.likeCount(file), 20);
      final beforeWrite = likes.beginSnapshot();
      await likes.toggle(file, (_) async {});
      likes.applyCatalog([track(true, count: 200)], beforeWrite);
      expect(likes.isLiked(file), isFalse);
      expect(likes.likeCount(file), 19);
    },
  );

  test(
    'snapshot started during a write stays stale after it completes',
    () async {
      await seed(likes, false);
      final gate = Completer<void>();
      final saving = likes.toggle(file, (_) => gate.future);
      final snapshot = likes.beginSnapshot();
      gate.complete();
      await saving;
      likes.applyCatalog([track(false, count: 100)], snapshot);
      expect(likes.isLiked(file), isTrue);
      expect(likes.likeCount(file), 11);
      likes.applyCatalog([track(true, count: 50)], likes.beginSnapshot());
      expect(likes.likeCount(file), 50);
    },
  );

  test('idempotent targets after a failure do not decrement twice', () async {
    await seed(likes, true, count: 1);
    final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
    var calls = 0;
    Future<void> submit(bool _) => gates[calls++].future;
    final first = likes.toggle(file, submit);
    final second = likes.toggle(file, submit);
    final secondError = expectLater(second, throwsStateError);
    final third = likes.toggle(file, submit);
    gates[0].complete();
    await first;
    gates[1].completeError(StateError('rejected'));
    await secondError;
    gates[2].complete();
    await third;
    expect(likes.isLiked(file), isFalse);
    expect(likes.likeCount(file), 0);
  });

  test(
    'disposal cancels queued writes before the next account can submit',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      Future<void> submit(bool _) {
        calls++;
        return gate.future;
      }

      final first = likes.toggle(file, submit);
      final second = likes.toggle(file, submit);
      await flush();
      expect(calls, 1);
      likes.dispose();
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
    },
  );

  test(
    'counts cannot be negative and disposed states cannot publish',
    () async {
      await seed(likes, true, count: 0);
      final gate = Completer<void>();
      final saving = likes.toggle(file, (_) => gate.future);
      expect(likes.likeCount(file), 0);
      var notifications = 0;
      likes.addListener(() => notifications++);
      likes.dispose();
      gate.complete();
      await saving;
      likes.applyCatalog([track(true)], likes.beginSnapshot());
      expect(notifications, 0);
    },
  );
}

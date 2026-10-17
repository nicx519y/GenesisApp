import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_likes.dart';

const file = '001.mp3';
MusicLikeStatus status(bool liked, [String name = file]) =>
    MusicLikeStatus(file: name, isLiked: liked);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MiniPhoneMusicLikes likes;
  setUp(() => likes = MiniPhoneMusicLikes());
  tearDown(() => likes.dispose());

  test(
    'loads server likes and updates synchronously before a submission completes',
    () async {
      await likes.loadStatus(file, () async => status(true));
      final gate = Completer<void>();
      final pending = likes.toggle(file, (liked) {
        expect(liked, isFalse);
        return gate.future;
      });
      expect(likes.isLiked(file), isFalse);
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
        await likes.loadStatus(file, () async => status(initial));
        final gate = Completer<void>();
        final pending = likes.toggle(file, (_) => gate.future);
        expect(likes.isLiked(file), !initial);
        final error = ApiException(message: '数据库繁忙', code: 5001);
        final assertion = expectLater(pending, throwsA(same(error)));
        gate.completeError(error);
        await assertion;
        expect(likes.isLiked(file), initial);
      },
    );
  }

  test(
    'a delayed status response cannot overwrite an optimistic tap',
    () async {
      final read = Completer<MusicLikeStatus>();
      final fetching = likes.loadStatus(file, () => read.future);
      final write = Completer<void>();
      final saving = likes.toggle(file, (_) => write.future);
      read.complete(status(false));
      await fetching;
      expect(likes.isLiked(file), isTrue);
      var reads = 0;
      await likes.loadStatus(file, () async {
        reads++;
        return status(false);
      });
      expect(reads, 0);
      write.complete();
      await saving;
      expect(likes.isLiked(file), isTrue);
    },
  );

  test(
    'rapid taps submit in order and latest failure restores last confirmed state',
    () async {
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
    },
  );

  test(
    'old failure cannot roll back a newer tap, and the queue continues',
    () async {
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
    'mismatched status is rejected and disposal suppresses pending notifications',
    () async {
      await expectLater(
        likes.loadStatus(file, () async => status(true, '002.mp3')),
        throwsFormatException,
      );
      final gate = Completer<void>();
      final saving = likes.toggle(file, (_) => gate.future);
      likes.dispose();
      gate.complete();
      await saving;
    },
  );
}

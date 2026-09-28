import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/personalization/fixture.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_personalization_profile.dart';

void main() {
  final request = {
    'runId': 'run-1',
    'version': 1,
    'mode': 'completed',
    'gender': 'Male',
    'age': '18-24',
  };
  for (final mode in ['completed', 'first_run', 'preserve']) {
    test(
      '$mode owns one snapshot, isolates owners and restores once',
      () async {
        const String? uid = null;
        var writes = 0;
        final before = completedMockPersonalization('Female', '25-34');
        final data = <String, Map<String, Object?>>{
          'device:test': Map.of(before),
          'uid:other': Map.of(before),
        };
        final fixture = PersonalizationFixture(
          identity: () async => uid,
          owner: () async => 'device:test',
          snapshot: (o) => data[o] == null ? null : Map.of(data[o]!),
          write: (o, v) {
            writes++;
            if (v == null) {
              data.remove(o);
            } else {
              data[o] = Map.of(v);
            }
          },
          observed: () => {
            'loaded': true,
            'completed': data['device:test']?['completed'] == true,
          },
        );
        final p = {...request, 'mode': mode};
        final receipt = await fixture.call('prepare', p, false) as Map;
        expect(receipt['before'], before);
        expect(await fixture.call('prepare', p, true), receipt);
        expect(writes, mode == 'preserve' ? 0 : 1);
        expect(data['uid:other'], before);
        expect(
          data['device:test']?['completed'],
          mode == 'first_run' ? null : true,
        );
        if (mode == 'completed') {
          expect(data['device:test']?['origin_feed_gender'], 'Female');
        }
        expect(
          (await fixture.call('read', {'runId': 'run-1'}, true)
              as Map)['identityUnchanged'],
          true,
        );
        expect(
          (await fixture.call('restore', {'runId': 'run-1'}, true)
              as Map)['restored'],
          true,
        );
        await fixture.call('restore', {'runId': 'run-1'}, true);
        expect(data['device:test'], before);
        expect(writes, mode == 'preserve' ? 0 : 2);
        await expectLater(fixture.call('prepare', p, false), throwsStateError);
      },
    );
  }
  test(
    'rejects late, conflicting, foreign and identity-changing requests',
    () async {
      String? uid;
      Map<String, Object?>? profile;
      final f = PersonalizationFixture(
        identity: () async => uid,
        owner: () async => 'owner',
        snapshot: (_) => profile,
        write: (_, v) => profile = v,
        observed: () => {},
      );
      await expectLater(f.call('prepare', request, true), throwsStateError);
      expect(profile, null);
      await f.call('prepare', request, false);
      await expectLater(
        f.call('prepare', {...request, 'age': '25-34'}, false),
        throwsStateError,
      );
      await expectLater(
        f.call('restore', {'runId': 'foreign'}, true),
        throwsStateError,
      );
      uid = 'other';
      await expectLater(
        f.call('read', {'runId': 'run-1'}, true),
        throwsStateError,
      );
      await expectLater(
        f.call('restore', {'runId': 'run-1'}, true),
        throwsStateError,
      );
      expect(profile?['completed'], true);
    },
  );
  test('independent runs do not inherit previous completed profiles', () async {
    Map<String, Object?>? profile;
    PersonalizationFixture create() => PersonalizationFixture(
      identity: () async => null,
      owner: () async => 'guest',
      snapshot: (_) => profile,
      write: (_, v) => profile = v,
      observed: () => {},
    );
    for (final run in ['one', 'two']) {
      final f = create();
      final r =
          await f.call('prepare', {...request, 'runId': run}, false) as Map;
      expect(r['before'], null);
      await f.call('restore', {'runId': run}, true);
      expect(profile, null);
    }
  });
  test(
    'cleanup verifies restored data rather than trusting mutation acknowledgment',
    () async {
      Map<String, Object?>? profile;
      bool fail = false;
      final f = PersonalizationFixture(
        identity: () async => null,
        owner: () async => 'guest',
        snapshot: (_) => profile,
        write: (_, v) {
          if (!fail) profile = v;
        },
        observed: () => {},
      );
      await f.call('prepare', request, false);
      fail = true;
      await expectLater(
        f.call('restore', {'runId': 'run-1'}, true),
        throwsStateError,
      );
    },
  );
}

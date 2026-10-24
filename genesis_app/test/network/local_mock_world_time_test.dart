import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';

void main() {
  test(
    'world mock exposes the latest completed time in list info and detail',
    () async {
      final api = GenesisApi(useMock: true);
      final page = await api.v1.world.list(pn: 1, rn: 1);
      final listed = ((page['list'] as List).first as Map)['info'] as Map;
      final id = listed['world_id'] as String;
      Future<void> check() async {
        final detail = await api.v1.world.detail(worldId: id);
        final ticks =
            (detail['ticks'] as List)
                .cast<Map>()
                .where((t) => t['status'] == 50)
                .toList()
              ..sort((a, b) {
                final tick = (b['tick_no'] as int).compareTo(
                  a['tick_no'] as int,
                );
                return tick != 0
                    ? tick
                    : (b['sub_tick_no'] as int).compareTo(
                        a['sub_tick_no'] as int,
                      );
              });
        final expected = (ticks.first['tick_result'] as Map)['current_time'];
        expect(
          expected,
          isA<String>().having((s) => s.isNotEmpty, 'nonempty', isTrue),
        );
        expect((detail['info'] as Map)['current_time'], expected);
        expect(
          ((await api.v1.world.info(worldId: id))['info']
              as Map)['current_time'],
          expected,
        );
        final refreshed = await api.v1.world.list(pn: 1, rn: 1);
        expect(
          (((refreshed['list'] as List).first as Map)['info']
              as Map)['current_time'],
          expected,
        );
      }

      await check();
      await api.v1.world.tick(worldId: id);
      await check();
    },
  );
}

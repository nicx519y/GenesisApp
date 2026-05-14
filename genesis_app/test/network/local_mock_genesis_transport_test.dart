import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';

void main() {
  test('local mock supports origin world and chat flow', () async {
    final api = GenesisApi(useMock: true);

    await api.bindDevice(did: 'device_mock_1');

    final search = await api.search(query: 'steam', limit: 20);
    expect(search.origins.isNotEmpty, true);

    final origins = await api.getOrigins(limit: 20, offset: 0);
    expect(origins.data.isNotEmpty, true);

    final firstOrigin = origins.data.first;
    final detail = await api.getOrigin(firstOrigin.oid);
    expect(detail.name.isNotEmpty, true);

    final world = await api.launchWorld(
      originId: firstOrigin.id,
      worldviewId: firstOrigin.oid,
      worldName: firstOrigin.name,
    );
    expect(world.wid.isNotEmpty, true);

    final worldDetail = await api.getWorld(world.wid);
    expect(worldDetail.worldLocations.isNotEmpty, true);

    final before = await api.getLocationMessages(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      limit: 50,
      offset: 0,
    );

    await api.sendMessage(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      content: 'hello from mock',
    );

    final after = await api.getLocationMessages(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      limit: 50,
      offset: 0,
    );

    expect(after.data.length >= before.data.length, true);
    expect(after.data.first.content.isNotEmpty, true);
  });
}

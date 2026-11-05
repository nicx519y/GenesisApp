import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';

void main() {
  test(
    'launch mock keeps five preset roles and adds only a custom identity',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.com/api/',
        transport: LocalMockGenesisTransport.isolated(),
      );
      final created = await client.post<Map>(
        'v1/origin/create',
        body: {
          'origin_name': 'Launch test',
          'characters': List.generate(
            5,
            (index) => {
              'char_id': 'char_${index + 1}',
              'name': 'Role $index',
              'identity': 'Identity $index',
              'personality': 'Personality $index',
              'bio': 'Setting $index',
              'goal': 'Goal $index',
              'avatar': '',
            },
          ),
        },
      );
      final oid = (created['data'] as Map)['info']['origin_id'];
      final launched = await client.post<Map>(
        'v1/origin/launch',
        body: {
          'origin_id': oid,
          'preset_character_id': 'char_2',
          'preset_character_override': {
            'name': 'Edited player',
            'bio': 'Accepted but ignored setting',
            'avatar': 'https://example.com/player.png',
          },
        },
      );
      final wid = (launched['data'] as Map)['world_id'];
      final detail = await client.get<Map>(
        'v1/world/detail',
        query: {'world_id': wid},
      );
      final roles = (detail['data'] as Map)['characters'] as List;
      expect(roles, hasLength(5));
      final selected = roles.cast<Map>().singleWhere(
        (item) => item['char_id'] == 'char_2',
      );
      expect(selected['name'], 'Edited player');
      expect(selected['player_uid'], isNotEmpty);
      expect(selected['description'], ''); // Current server limitation.
      expect(selected['goal'], '');
      expect(roles.cast<Map>().first['goal'], 'Goal 0');

      await client.post<Map>(
        'v1/origin/launch',
        body: {
          'origin_id': oid,
          'custom_role': {'name': 'New identity', 'bio': 'Custom setting'},
        },
      );
      final customDetail = await client.get<Map>(
        'v1/world/detail',
        query: {'world_id': wid},
      );
      final customRoles = (customDetail['data'] as Map)['characters'] as List;
      expect(customRoles, hasLength(6));
      expect(customRoles.cast<Map>().last['char_id'], 'char_6');
      expect(customRoles.cast<Map>().last['description'], 'Custom setting');
      final original = await client.get<Map>(
        'v1/origin/detail',
        query: {'origin_id': oid},
      );
      final originalRoles = (original['data'] as Map)['characters'] as List;
      expect(originalRoles, hasLength(5));
      expect(originalRoles.cast<Map>().elementAt(1)['name'], 'Role 1');
    },
  );
}

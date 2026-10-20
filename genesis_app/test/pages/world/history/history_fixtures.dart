import 'dart:convert';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/network/models/world.dart';

Map<String, dynamic> historyJson(
  String id, {
  String type = 'character',
  String content = 'Hello',
  List<String> locations = const ['A'],
  int version = 0,
  int tick = 0,
  int subTick = 0,
}) => {
  'global_message_id': id,
  'type': type,
  'tick': tick,
  'sub_tick': subTick,
  'sender_id': 'c1',
  'sender_name': 'Role',
  'user_id': null,
  'message_type': 'text',
  'content': content,
  'min_app_version': version,
  'current_time': 'Day 1',
  'created_at': '2026-10-19T12:00:00+08:00',
  'location_refs': locations,
};
WorldHistoryMessage historyMessage(
  String id, {
  String type = 'character',
  String content = 'Hello',
  List<String> locations = const ['A'],
  int version = 0,
  int tick = 0,
  int subTick = 0,
}) => WorldHistoryMessage.fromJson(
  historyJson(
    id,
    type: type,
    content: content,
    locations: locations,
    version: version,
    tick: tick,
    subTick: subTick,
  ),
);
WorldHistoryPage historyPage(
  List<String> ids, {
  String cursor = '',
  String world = 'w',
  bool? more,
}) => WorldHistoryPage(
  worldId: world,
  messages: ids.map((id) => historyMessage(id)).toList(),
  hasMore: more ?? cursor.isNotEmpty,
  cursor: cursor,
);
WorldDetail historyWorld({int locations = 2, int characters = 1}) =>
    WorldDetail.fromJson({
      'world_id': 'w',
      'characters': [
        for (var i = 1; i <= characters; i++)
          {'char_id': 'c$i', 'name': 'Character $i'},
      ],
    }).copyWith(
      locationTree: [
        for (var i = 0; i < locations; i++)
          LocationTreeNode<Map<String, dynamic>>(
            id: String.fromCharCode(65 + i),
            parentId: '',
            depth: 0,
            children: const [],
            value: {
              'location_id': String.fromCharCode(65 + i),
              'location_name': 'Place ${String.fromCharCode(65 + i)}',
            },
          ),
      ],
    );
String tickContent({Object? statuses, Object? events, Object? moves}) =>
    jsonEncode({
      'current_time': 'Day 5',
      'global': 'The rain begins.',
      'global_status': statuses,
      'story_events': events,
      'characters_moved': moves,
    });

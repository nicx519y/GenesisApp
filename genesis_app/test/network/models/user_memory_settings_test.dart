import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/user_memory_settings.dart';

void main() {
  test('parses global settings and zero or positive world usage', () {
    final global = UserMemorySettings.fromJson(const <String, dynamic>{
      'memory_tokens': 12400,
      'min_memory_tokens': 8000,
      'max_memory_tokens': 1000000,
    });
    final unusedWorld = UserMemorySettings.fromJson(const <String, dynamic>{
      'memory_tokens': 12400,
      'min_memory_tokens': 8000,
      'max_memory_tokens': 1000000,
      'world_id': 'w_1',
      'memory_used_tokens': 0,
    });
    final usedWorld = UserMemorySettings.fromJson(const <String, dynamic>{
      'memory_tokens': 12400,
      'min_memory_tokens': 8000,
      'max_memory_tokens': 1000000,
      'world_id': 'w_2',
      'memory_used_tokens': 12001,
    });

    expect(global.memoryTokens, 12400);
    expect(global.worldId, isNull);
    expect(global.memoryUsedTokens, isNull);
    expect(unusedWorld.worldId, 'w_1');
    expect(unusedWorld.memoryUsedTokens, 0);
    expect(usedWorld.worldId, 'w_2');
    expect(usedWorld.memoryUsedTokens, 12001);
  });

  test('rejects missing, string, and decimal integer fields', () {
    for (final field in <String>[
      'memory_tokens',
      'min_memory_tokens',
      'max_memory_tokens',
    ]) {
      for (final invalid in <Object?>[null, '12400', 12400.0]) {
        final json = <String, dynamic>{
          'memory_tokens': 12400,
          'min_memory_tokens': 8000,
          'max_memory_tokens': 1000000,
        };
        if (invalid == null) {
          json.remove(field);
        } else {
          json[field] = invalid;
        }
        expect(() => UserMemorySettings.fromJson(json), throwsFormatException);
      }
    }

    expect(
      () => UserMemorySettings.fromJson(const <String, dynamic>{
        'memory_tokens': 12400,
        'min_memory_tokens': 8000,
        'max_memory_tokens': 1000000,
        'memory_used_tokens': '0',
      }),
      throwsFormatException,
    );
    expect(
      () => UserMemorySettings.fromJson(const <String, dynamic>{
        'memory_tokens': 12400,
        'min_memory_tokens': 8000,
        'max_memory_tokens': 1000000,
        'memory_used_tokens': 1.5,
      }),
      throwsFormatException,
    );
    expect(
      () => UserMemorySettings.fromJson(const <String, dynamic>{
        'memory_tokens': 12400,
        'min_memory_tokens': 8000,
        'max_memory_tokens': 1000000,
        'world_id': 1,
      }),
      throwsFormatException,
    );
  });
}

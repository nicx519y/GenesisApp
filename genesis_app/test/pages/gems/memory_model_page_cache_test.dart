import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page_cache.dart';

void main() {
  test('model catalog requests are single-flight per user and World', () async {
    final firstCache = MemoryModelPageCache();
    final secondCache = MemoryModelPageCache();
    final completer = Completer<GemModelCatalog>();
    var loads = 0;

    Future<GemModelCatalog> load() {
      loads += 1;
      return completer.future;
    }

    final first = firstCache.loadModelCatalog(
      uid: 'u_1',
      worldId: 'world_1',
      loader: load,
    );
    final second = secondCache.loadModelCatalog(
      uid: 'u_1',
      worldId: 'world_1',
      loader: load,
    );

    expect(loads, 1);
    completer.complete(_catalog);
    expect(await first, same(_catalog));
    expect(await second, same(_catalog));
    firstCache.dispose();
    secondCache.dispose();
  });

  test(
    'permission denial is negatively cached for the same user and World',
    () async {
      final cache = MemoryModelPageCache();
      var loads = 0;

      Future<GemModelCatalog> denied() async {
        loads += 1;
        throw ApiException(
          message: 'user has no permission',
          code: 10011,
          kind: ApiExceptionKind.business,
        );
      }

      expect(
        await cache.loadModelCatalog(
          uid: 'u_1',
          worldId: 'world_1',
          loader: denied,
        ),
        isNull,
      );
      expect(
        await cache.loadModelCatalog(
          uid: 'u_1',
          worldId: 'world_1',
          loader: denied,
        ),
        isNull,
      );
      expect(loads, 1);

      expect(
        await cache.loadModelCatalog(
          uid: 'u_2',
          worldId: 'world_1',
          loader: () async {
            loads += 1;
            return _catalog;
          },
        ),
        same(_catalog),
      );
      expect(loads, 2);

      expect(
        await cache.loadModelCatalog(
          uid: 'u_1',
          worldId: 'world_2',
          loader: () async {
            loads += 1;
            return _catalog;
          },
        ),
        same(_catalog),
      );
      expect(loads, 3);
      cache.dispose();

      final nextPageCache = MemoryModelPageCache();
      expect(
        await nextPageCache.loadModelCatalog(
          uid: 'u_1',
          worldId: 'world_1',
          loader: () async {
            loads += 1;
            return _catalog;
          },
        ),
        same(_catalog),
      );
      expect(loads, 4);
      nextPageCache.dispose();
    },
  );

  test('non-permission failures remain retryable', () async {
    final cache = MemoryModelPageCache();
    var loads = 0;

    await expectLater(
      cache.loadModelCatalog(
        uid: 'u_1',
        worldId: 'world_1',
        loader: () async {
          loads += 1;
          throw StateError('temporary failure');
        },
      ),
      throwsStateError,
    );
    expect(
      await cache.loadModelCatalog(
        uid: 'u_1',
        worldId: 'world_1',
        loader: () async {
          loads += 1;
          return _catalog;
        },
      ),
      same(_catalog),
    );
    expect(loads, 2);
    cache.dispose();
  });
}

const _catalog = GemModelCatalog(selectedModelCode: 'model_1', groups: []);

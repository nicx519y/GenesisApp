import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/search/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores the 50 most recent unique search queries', () async {
    const store = SearchHistoryStore();

    for (var index = 0; index < 55; index += 1) {
      await store.add('query $index');
    }

    var history = await store.load();
    expect(history, hasLength(50));
    expect(history.first, 'query 54');
    expect(history.last, 'query 5');

    history = await store.add(' query 10 ');
    expect(history, hasLength(50));
    expect(history.first, 'query 10');
    expect(history.where((query) => query == 'query 10'), hasLength(1));
  });

  test('ignores empty search queries', () async {
    const store = SearchHistoryStore();

    await store.add('origin');
    final history = await store.add('   ');

    expect(history, <String>['origin']);
  });
}

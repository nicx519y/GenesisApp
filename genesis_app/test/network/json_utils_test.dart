import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/json_utils.dart';

void main() {
  test('asString sanitizes malformed UTF-16 from decoded JSON values', () {
    expect(asString('hello \uD800 world'), 'hello \uFFFD world');
    expect(asString('hello \uDC00 world'), 'hello \uFFFD world');
    expect(asString(null, fallback: 'fallback \uD800'), 'fallback \uFFFD');
  });

  test('asString preserves valid surrogate pairs', () {
    expect(asString('hello \uD83D\uDE00'), 'hello \uD83D\uDE00');
  });
}

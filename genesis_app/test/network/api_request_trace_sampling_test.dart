import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_request_trace_sampling.dart';

void main() {
  setUp(ApiRequestTraceSampling.resetForTesting);
  tearDown(ApiRequestTraceSampling.resetForTesting);

  test('API trace sampling starts disabled', () {
    expect(ApiRequestTraceSampling.enabledForLaunch, isFalse);
  });

  test('API trace sampling uses one launch decision', () {
    ApiRequestTraceSampling.configureForLaunch(0.1, randomValue: 0.09);
    expect(ApiRequestTraceSampling.enabledForLaunch, isTrue);

    ApiRequestTraceSampling.configureForLaunch(0.1, randomValue: 0.1);
    expect(ApiRequestTraceSampling.enabledForLaunch, isTrue);
  });

  test('API trace sampling clamps invalid rates', () {
    ApiRequestTraceSampling.configureForLaunch(-1, randomValue: 0);
    expect(ApiRequestTraceSampling.enabledForLaunch, isFalse);

    ApiRequestTraceSampling.resetForTesting();
    ApiRequestTraceSampling.configureForLaunch(2, randomValue: 0.999);
    expect(ApiRequestTraceSampling.enabledForLaunch, isTrue);

    ApiRequestTraceSampling.resetForTesting();
    ApiRequestTraceSampling.configureForLaunch(double.nan, randomValue: 0);
    expect(ApiRequestTraceSampling.enabledForLaunch, isFalse);
  });
}

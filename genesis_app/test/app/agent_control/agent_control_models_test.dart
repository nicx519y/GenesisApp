import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_models.dart';

void main() {
  test('parses request defaults', () {
    final request = AgentControlRequest.fromJson({
      'method': 'app.ping',
      'params': {'value': 1},
    });

    expect(request.id, 'app.ping');
    expect(request.method, 'app.ping');
    expect(request.params, {'value': 1});
    expect(request.timeoutMs, 10000);
    expect(request.dryRun, false);
  });

  test('parses timeout and dry run values', () {
    final request = AgentControlRequest.fromJson({
      'id': '123',
      'method': 'app.state',
      'timeoutMs': '2500',
      'dryRun': 'true',
    });

    expect(request.id, '123');
    expect(request.timeoutMs, 2500);
    expect(request.dryRun, true);
  });

  test('rejects invalid request bodies', () {
    expect(
      () => AgentControlRequest.fromJson(null),
      throwsA(isA<AgentControlException>()),
    );
    expect(
      () => AgentControlRequest.fromJson({'method': ''}),
      throwsA(isA<AgentControlException>()),
    );
  });
}

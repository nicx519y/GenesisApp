import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_server.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('supports overlapping starts across server instances', () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final services = ServiceRegistry.build(
      config: AppConfig(
        useMock: true,
        agentControlEnabled: true,
        agentControlPort: port,
        agentControlToken: 'test-control-token',
      ),
    );
    final firstServer = AgentControlServer();
    final secondServer = AgentControlServer();

    try {
      await Future.wait([
        firstServer.start(services),
        firstServer.start(services),
        secondServer.start(services),
      ]);

      expect(firstServer.isRunning, isTrue);
      expect(secondServer.isRunning, isTrue);
    } finally {
      await Future.wait([
        firstServer.stop(force: true),
        secondServer.stop(force: true),
      ]);
      services.dispose();
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('world owner rebuilds chatroom authentication without timers', () {
    final worldPage = File(
      'lib/pages/world/world_page.dart',
    ).readAsStringSync();
    final locationChat = File(
      'lib/pages/world/world_location_chat_host.dart',
    ).readAsStringSync();
    final recovery = worldPage.substring(
      worldPage.indexOf(
        'Future<void> _performWorldChatroomAuthenticationRecovery()',
      ),
      worldPage.indexOf('void _handleWorldChatroomState('),
    );

    expect(worldPage, contains('onFailure: _handleWorldChatroomFailure'));
    expect(recovery, contains('await service.dispose()'));
    expect(recovery, contains('final loggedIn = await ensureGenesisLogin'));
    expect(recovery, contains('await replacement.connect('));
    expect(recovery, contains('await replacement.join('));
    expect(recovery, isNot(contains('Future<void>.delayed(')));
    expect(recovery, isNot(contains('Timer(')));
    expect(locationChat, contains('unauthorizedHandledByOwner: true'));
  });
}

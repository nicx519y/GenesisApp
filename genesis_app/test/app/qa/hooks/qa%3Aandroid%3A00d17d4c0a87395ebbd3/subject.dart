import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/contract_fixture.dart';

Future<ChatPanelFixture> mountSubject(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final services = ServiceRegistry.build(
    config: const AppConfig(apiEnvironment: 'mock', collectEnabled: false),
    sessionStoreOverride: MemoryUserSessionStore(),
    chatroomMessagesOverride: MemoryChatroomMessageStorage(),
  );
  final nav = GlobalKey<NavigatorState>();
  final key = GlobalKey();
  await tester.pumpWidget(
    AppServicesScope(
      services: services,
      child: MaterialApp(
        theme: GenesisTheme.dark(),
        navigatorKey: nav,
        home: Scaffold(body: SizedBox(key: key)),
      ),
    ),
  );
  final fixture = ChatPanelFixture(
    nav.currentState!,
    ModalRoute.of(key.currentContext!)!,
    services,
  );
  final pending = fixture.prepare();
  await tester.pump();
  await pending;
  await tester.pump(const Duration(seconds: 1));
  return fixture;
}

Future<void> closeSubject(WidgetTester tester, ChatPanelFixture fixture) async {
  if (!fixture.released) {
    final pending = fixture.restore('test-session');
    await tester.pump();
    await pending;
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

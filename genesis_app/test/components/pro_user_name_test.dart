import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/membership/user_membership_status_store.dart';
import 'package:genesis_flutter_android/components/gems/pro_membership_badge.dart';
import 'package:genesis_flutter_android/components/gems/pro_user_name.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'long names retain ellipsis, centered badge, and shared lookup at text scales',
    (tester) async {
      var requests = 0;
      final store = UserMembershipStatusStore(
        loadUser: (uid) async {
          requests++;
          return {
            'user': {'uid': uid, 'membership_status': 1},
          };
        },
      );
      final services = servicesWith(store);
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              theme: GenesisTheme.dark(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        child: ProUserName(
                          uid: 'u',
                          fontSize: 20,
                          child: Text(
                            'A very long name 中文名字',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Name'),
                            ProUserBadge.span(uid: 'u', fontSize: 12),
                            const TextSpan(text: ': reply'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProMembershipBadge), findsNWidgets(2));
        final name = tester.getRect(find.text('A very long name 中文名字'));
        final badge = tester.getRect(find.byType(ProMembershipBadge).first);
        expect(badge.center.dy, closeTo(name.center.dy, 0.01));
        expect(badge.width, closeTo(24 * scale, 0.01));
        expect(badge.height, closeTo(17 * scale, 0.01));
        expect(
          badge.right,
          lessThanOrEqualTo(tester.getRect(find.byType(ProUserName)).right),
        );
        expect(tester.takeException(), isNull);
      }
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'nonmember unknown deleted and changed targets have no badge or reserved gap',
    (tester) async {
      final queried = <String>[];
      final store = UserMembershipStatusStore(
        loadUser: (uid) async {
          queried.add(uid);
          return {
            'user': {
              'uid': uid,
              if (uid != 'unknown')
                'membership_status': uid == 'active' ? 1 : 2,
            },
          };
        },
      );
      final services = servicesWith(store);
      for (final uid in ['active', 'expired', 'unknown', 'deleted']) {
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ProUserName(
                    uid: uid,
                    deleted: uid == 'deleted',
                    fontSize: 14,
                    child: const Text('Name', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(ProMembershipBadge),
          uid == 'active' ? findsOneWidget : findsNothing,
        );
        if (uid != 'active') {
          expect(
            tester.getSize(find.byType(ProUserName)).width,
            tester.getSize(find.text('Name')).width,
          );
        }
      }
      expect(queried, ['active', 'expired', 'unknown']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

AppServices servicesWith(UserMembershipStatusStore store) {
  final previousPlatform = debugDefaultTargetPlatformOverride;
  late final AppServices base;
  try {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  } finally {
    debugDefaultTargetPlatformOverride = previousPlatform;
  }
  addTearDown(base.dispose);
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: base.sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: base.api,
    chatroom: base.chatroom,
    chatroomMessages: base.chatroomMessages,
    directMessageConversations: base.directMessageConversations,
    directMessageMessages: base.directMessageMessages,
    appVersionCheck: base.appVersionCheck,
    externalUrlOpener: base.externalUrlOpener,
    userMemberships: store,
  );
}

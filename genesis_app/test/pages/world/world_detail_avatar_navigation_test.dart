import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mini_phone_chat_backend.dart';
import 'history/history_fixtures.dart';
import 'history/world_history_widget_test.dart' show Backend, Harness;

void main() {
  testWidgets('detail avatars open the selected role chat over the sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final h = Harness(Backend());
    final world = historyWorld().copyWith(
      relationStatus: 'owner',
      characters: [
        {'char_id': 'self', 'name': 'My role', 'player_uid': 'me'},
        {'name': 'Missing role ID'},
        {'char_id': 'c2', 'name': 'Other role'},
      ],
    );
    final backend = PhoneBackend()..uid = 'me';
    final store = backend.store();
    final session = MiniPhoneSession(worldId: world.worldId, data: store);
    session.resume.screen = MiniPhoneScreen.chat;
    session.resume.liveContact = const PhonePerson('old', 'Previous chat', '');
    final selection = ValueNotifier(
      const WorldBottomSheetSelection(
        kind: WorldBottomSheetKind.detail,
        eventsLatestRevision: 0,
      ),
    );
    final worlds = ValueNotifier<WorldDetail?>(world);
    final notices = ValueNotifier<List<WorldNewUserJoinNotice>>([]);
    final recap = WorldRecapCache();
    final events = WorldSectionsEventsCache();
    addTearDown(selection.dispose);
    addTearDown(worlds.dispose);
    addTearDown(notices.dispose);
    addTearDown(recap.dispose);
    addTearDown(session.dispose);

    await tester.runAsync(() => store.ready);
    await tester.pumpWidget(h.build(world, shown: false));
    unawaited(
      showModalBottomSheet<void>(
        context: h.navigator.currentContext!,
        isScrollControlled: true,
        enableDrag: false,
        builder: (_) => MiniPhoneSessionScope(
          session: session,
          worldDetailReady: true,
          child: WorldSingleSectionBottomSheet(
            selectionListenable: selection,
            services: h.services,
            initialWorld: world,
            worldListenable: worlds,
            newUserJoinNoticesListenable: notices,
            eventsCache: events,
            recapCache: recap,
            currentUid: 'me',
            recentChatLocationIds: const {},
            onLocationTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(WorldDetailSectionListView),
      matching: find.byType(Scrollable),
    );
    Finder avatar(String name) => find.byWidgetPredicate(
      (widget) => widget is GenesisCharacterAvatar && widget.name == name,
    );

    for (final name in ['My role', 'Missing role ID']) {
      await tester.scrollUntilVisible(
        avatar(name),
        100,
        scrollable: scrollable,
      );
      await tester.tap(avatar(name));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPhonePage), findsNothing);
    }

    final target = avatar('Other role');
    await tester.scrollUntilVisible(target, 100, scrollable: scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    final offset = position.pixels;
    await tester.tap(target);
    await tester.tap(target, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final phone = tester.widget<MiniPhonePage>(find.byType(MiniPhonePage));
    expect(phone.session, same(session));
    expect(phone.entrySource, 'world_detail_avatar');
    final chat = tester.widget<MiniPhoneLiveChat>(
      find.byType(MiniPhoneLiveChat),
    );
    expect(chat.store, same(store));
    expect(chat.person.id, 'c2');
    expect(chat.person.name, 'Other role');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(selection.value.kind, WorldBottomSheetKind.detail);
    expect(tester.state<ScrollableState>(scrollable).position, same(position));
    expect(position.pixels, offset);
    expect(session.isDisposed, isFalse);
    await h.close(tester);
    expect(tester.takeException(), isNull);
  });
}

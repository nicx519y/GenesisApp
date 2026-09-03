import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/world_new_content_debug_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/world_new_badge.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/world/world_constants.dart'
    show worldCharacterAvatarLogicalSize;
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_fixed_underline_indicator.dart';
import 'package:genesis_flutter_android/ui/components/genesis_tab_bar.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    worldNewContentDebugSettings.resetForTesting();
  });

  tearDown(worldNewContentDebugSettings.resetForTesting);

  testWidgets('mention sheet reuses Genesis tabs and swipes between lists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'char-1',
          name: 'Alice',
          type: ChatMentionType.character,
          imageUrl: 'https://cdn.example.com/alice.webp',
        ),
      ],
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'loc-1',
          name: 'Moon Harbor',
          type: ChatMentionType.location,
          subtitle: 'Silver Coast',
          imageUrl: 'https://cdn.example.com/moon-harbor.webp',
          isCurrentLocation: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('location-chat-mention-sheet')),
          )
          .height,
      closeTo(844 / 2 * 0.8, 0.01),
    );
    final sheet = tester.widget<Material>(
      find.byKey(const ValueKey<String>('location-chat-mention-sheet')),
    );
    expect(sheet.color, const Color(0xFF1F1D24));
    final header = find.byKey(
      const ValueKey<String>('location-chat-mention-header'),
    );
    expect(tester.getSize(header).height, 48);
    final title = tester.widget<Text>(find.text('Mention'));
    expect(title.style?.fontSize, 16);
    expect(title.style?.height, 1.6);
    expect(title.style?.color, const Color(0xF2FFFFFF));
    expect(
      tester.getCenter(find.text('Mention')).dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(const ValueKey<String>('location-chat-mention-sheet')),
            )
            .dx,
        0.01,
      ),
    );
    final collapseButton = find.byKey(
      const ValueKey<String>('location-chat-mention-collapse'),
    );
    expect(tester.getSize(collapseButton), const Size.square(24));
    expect(
      tester.getTopLeft(collapseButton).dx - tester.getTopLeft(header).dx,
      16,
    );
    expect(
      tester.getTopLeft(collapseButton).dy - tester.getTopLeft(header).dy,
      17,
    );
    final collapseIcon = tester.widget<Icon>(
      find.descendant(of: collapseButton, matching: find.byType(Icon)),
    );
    expect(collapseIcon.icon, Icons.keyboard_arrow_down_rounded);
    expect(collapseIcon.size, 18);
    final mentionTabBar = tester.widget<GenesisTabBar>(
      find.byType(GenesisTabBar),
    );
    expect(mentionTabBar.labelColor, const Color(0xF2FFFFFF));
    expect(mentionTabBar.unselectedLabelColor, const Color(0xB8FFFFFF));
    expect(find.byType(GenesisBottomSheetDragDismissArea), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'location-chat-mention-tab-scroll-configuration',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).physics,
      isA<ClampingScrollPhysics>(),
    );
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    final indicator =
        tester.widget<TabBar>(find.byType(TabBar)).indicator!
            as GenesisFixedUnderlineIndicator;
    expect(indicator.width, 34);
    expect(indicator.height, 3);
    expect(indicator.color, GenesisColors.danger);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Everyone'), findsNothing);
    expect(
      find
          .byKey(
            const ValueKey<String>('location-chat-mention-character-char-1'),
          )
          .hitTestable(),
      findsOneWidget,
    );
    final characterAvatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(characterAvatar.size, 40);
    expect(characterAvatar.borderRadius, 8);
    expect(
      characterAvatar.url,
      resizeGenesisImageUrl(
        'https://cdn.example.com/alice.webp',
        logicalWidth: worldCharacterAvatarLogicalSize,
        devicePixelRatio: 2,
      ),
    );
    final characterName = tester.widget<Text>(find.text('Alice'));
    expect(characterName.style?.fontSize, 14);
    expect(characterName.style?.height, 1.4);
    expect(characterName.style?.color, const Color(0xF2FFFFFF));

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();
    expect(
      find
          .byKey(const ValueKey<String>('location-chat-mention-location-loc-1'))
          .hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey<String>('location-chat-mention-tab-view')),
      const Offset(-390, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find
          .byKey(const ValueKey<String>('location-chat-mention-location-loc-1'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('Silver Coast >'), findsOneWidget);
    final locationSubtitle = tester.widget<Text>(find.text('Silver Coast >'));
    expect(locationSubtitle.style?.fontSize, 12);
    expect(locationSubtitle.style?.fontWeight, FontWeight.w600);
    expect(locationSubtitle.style?.color, const Color(0x73FFFFFF));
    expect(tester.widget<Text>(find.text('Moon Harbor')).style?.fontSize, 14);
    final hereLabel = tester.widget<Text>(find.text('Here'));
    expect(hereLabel.style?.fontSize, 12);
    expect(hereLabel.style?.fontWeight, FontWeight.w600);
    expect(hereLabel.style?.color, const Color(0x73FFFFFF));
    expect(
      tester.getCenter(find.text('Here')).dx,
      greaterThan(tester.getCenter(find.text('Moon Harbor')).dx),
    );
    final locationNameRow = find
        .ancestor(of: find.text('Here'), matching: find.byType(Row))
        .first;
    expect(
      tester.widget<Row>(locationNameRow).crossAxisAlignment,
      CrossAxisAlignment.baseline,
    );
    expect(
      find.descendant(of: locationNameRow, matching: find.text('Moon Harbor')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ListView>(find.byType(ListView))
          .every((list) => list.physics is ClampingScrollPhysics),
      isTrue,
    );
  });

  testWidgets('location mentions never render an image', (tester) async {
    final catalog = ChatMentionCatalog(
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'loc-without-image',
          name: 'Hidden Valley',
          type: ChatMentionType.location,
          subtitle: 'Northern Range',
          imageUrl: 'https://cdn.example.com/ignored.webp',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );
    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    final locationRow = find.byKey(
      const ValueKey<String>(
        'location-chat-mention-location-loc-without-image',
      ),
    );
    expect(
      find.descendant(of: locationRow, matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.text('Northern Range >'), findsOneWidget);
  });

  testWidgets('mention rows show New badges for detail is_new entries', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'character-new',
          name: 'New Character',
          type: ChatMentionType.character,
          isNew: true,
        ),
      ],
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'location-new',
          name: 'New Location',
          type: ChatMentionType.location,
          isNew: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    final characterRow = find.byKey(
      const ValueKey<String>('location-chat-mention-character-character-new'),
    );
    expect(
      find.descendant(of: characterRow, matching: find.byType(WorldNewBadge)),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(
            find.descendant(
              of: characterRow,
              matching: find.text('New Character'),
            ),
          )
          .center
          .dy,
      closeTo(
        tester
            .getRect(
              find.descendant(
                of: characterRow,
                matching: find.byType(WorldNewBadge),
              ),
            )
            .center
            .dy,
        0.01,
      ),
    );

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    final locationRow = find.byKey(
      const ValueKey<String>('location-chat-mention-location-location-new'),
    );
    expect(
      find.descendant(of: locationRow, matching: find.byType(WorldNewBadge)),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(
            find.descendant(
              of: locationRow,
              matching: find.text('New Location'),
            ),
          )
          .center
          .dy,
      closeTo(
        tester
            .getRect(
              find.descendant(
                of: locationRow,
                matching: find.byType(WorldNewBadge),
              ),
            )
            .center
            .dy,
        0.01,
      ),
    );
  });

  testWidgets('Debug force switch shows New badges without changing entries', (
    tester,
  ) async {
    await worldNewContentDebugSettings.setForceNewBadges(true);
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'character-existing',
          name: 'Existing Character',
          type: ChatMentionType.character,
        ),
      ],
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'location-existing',
          name: 'Existing Location',
          type: ChatMentionType.location,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>(
          'location-chat-mention-character-new-badge-character-existing',
        ),
      ),
      findsOneWidget,
    );
    expect(catalog.newLocations, isEmpty);

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'location-chat-mention-location-new-badge-location-existing',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-title-new'),
      ),
      findsNothing,
    );
  });

  testWidgets('mention lists only show all entries and mark here characters', (
    tester,
  ) async {
    const here = ChatMentionEntry(
      id: 'char-here',
      name: 'Here Character',
      type: ChatMentionType.character,
    );
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        here,
        ChatMentionEntry(
          id: 'char-away',
          name: 'Away Character',
          type: ChatMentionType.character,
        ),
      ],
      currentLocationCharacters: const <ChatMentionEntry>[here],
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'location-new',
          name: 'New Harbor',
          subtitle: 'Silver Coast',
          type: ChatMentionType.location,
          isNew: true,
        ),
        ChatMentionEntry(
          id: 'location-old',
          name: 'Old Harbor',
          subtitle: 'Silver Coast',
          type: ChatMentionType.location,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(find.text('Here Character'), findsOneWidget);
    expect(find.text('Away Character'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-title-here'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-divider'),
      ),
      findsNothing,
    );
    final hereCharacterRow = find.byKey(
      const ValueKey<String>('location-chat-mention-character-char-here'),
    );
    expect(
      find.descendant(of: hereCharacterRow, matching: find.text('Here')),
      findsOneWidget,
    );
    final hereLabel = tester.widget<Text>(
      find.descendant(of: hereCharacterRow, matching: find.text('Here')),
    );
    expect(hereLabel.style?.fontSize, 12);
    expect(hereLabel.style?.fontWeight, FontWeight.w600);
    expect(hereLabel.style?.color, const Color(0x73FFFFFF));

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-title-new'),
      ),
      findsNothing,
    );
    expect(find.text('New Harbor'), findsOneWidget);
    expect(find.text('Old Harbor'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-divider'),
      ),
      findsNothing,
    );
  });

  testWidgets('Here label stays hidden without current location characters', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'char-away',
          name: 'Away Character',
          type: ChatMentionType.character,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(find.text('Here'), findsNothing);
    expect(find.text('Away Character'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('location-chat-mention-section-divider'),
      ),
      findsNothing,
    );
  });

  testWidgets('mention lists sort by name and render without dividers', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'character-a',
          name: 'Zelda',
          type: ChatMentionType.character,
        ),
        ChatMentionEntry(
          id: 'character-z',
          name: 'alice',
          type: ChatMentionType.character,
        ),
        ChatMentionEntry(
          id: 'character-m',
          name: 'Bob',
          type: ChatMentionType.character,
        ),
      ],
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'location-a',
          name: 'Zulu Harbor',
          type: ChatMentionType.location,
        ),
        ChatMentionEntry(
          id: 'location-z',
          name: 'amber Valley',
          type: ChatMentionType.location,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(
      tester.getTopLeft(find.text('alice')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bob')).dy,
      lessThan(tester.getTopLeft(find.text('Zelda')).dy),
    );
    expect(find.byType(Divider), findsNothing);

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('amber Valley')).dy,
      lessThan(tester.getTopLeft(find.text('Zulu Harbor')).dy),
    );
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('other player mention avatars use the red border', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      characters: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'npc-character',
          name: 'NPC Character',
          type: ChatMentionType.character,
        ),
        ChatMentionEntry(
          id: 'other-player',
          name: 'Other Player',
          type: ChatMentionType.character,
          isPlayerControlled: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    GenesisCharacterAvatar avatarFor(String id) {
      return tester.widget<GenesisCharacterAvatar>(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('location-chat-mention-character-$id'),
          ),
          matching: find.byType(GenesisCharacterAvatar),
        ),
      );
    }

    expect(avatarFor('npc-character').border, isNull);
    expect(
      avatarFor('other-player').border,
      Border.all(color: const Color(0xFFFF2442), width: 2),
    );
  });

  testWidgets('long mention list dismisses from a body drag at the top', (
    tester,
  ) async {
    final catalog = ChatMentionCatalog(
      locations: List<ChatMentionEntry>.generate(
        30,
        (index) => ChatMentionEntry(
          id: 'location-$index',
          name: 'Location $index',
          type: ChatMentionType.location,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey<String>('open-mention-sheet'),
              onPressed: () => showGenesisModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useSafeArea: false,
                builder: (_) => LocationChatMentionSheet(catalog: catalog),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-mention-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();

    final locationList = find
        .byKey(const PageStorageKey<String>('location-chat-location-mentions'))
        .hitTestable();
    expect(locationList, findsOneWidget);
    await tester.drag(locationList, const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('location-chat-mention-sheet')),
      findsNothing,
    );
  });
}

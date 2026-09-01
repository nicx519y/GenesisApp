import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/world_location_list.dart'
    show worldLocationCoverLogicalSize;
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/world/world_constants.dart'
    show worldCharacterAvatarLogicalSize;
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_tab_bar.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
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
          imageUrl: 'https://cdn.example.com/moon-harbor.webp',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationChatMentionSheet(catalog: catalog)),
      ),
    );

    expect(find.byType(GenesisTabBar), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
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
    expect(tester.widget<Text>(find.text('Alice')).style?.fontSize, 14);

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
    final locationImage = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(locationImage.width, 40);
    expect(locationImage.height, 40);
    expect(locationImage.borderRadius, BorderRadius.circular(8));
    expect(
      locationImage.imageUrl,
      resizeGenesisImageUrl(
        'https://cdn.example.com/moon-harbor.webp',
        logicalWidth: worldLocationCoverLogicalSize,
        devicePixelRatio: 2,
      ),
    );
    expect(tester.widget<Text>(find.text('Moon Harbor')).style?.fontSize, 14);
  });
}

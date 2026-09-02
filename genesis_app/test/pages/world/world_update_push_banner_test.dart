import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_update_push_banner.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

const _characterAvatarUrl =
    'https://cdn-001.worldo.ai/app/uploads/20260702/'
    '2072507310906806272_356_356.jpg?x-oss-process=image/format,webp';
const _locationImageUrl =
    'https://cdn-001.worldo.ai/app/uploads/20260705/'
    '2073569582257278976_800_1200.jpg?x-oss-process=image/format,webp';

void main() {
  testWidgets('world update push notices are shown sequentially', (
    WidgetTester tester,
  ) async {
    const notices = <WorldContentUpdateNotice>[
      WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.location,
        entityId: 'loc-new',
        name: 'New Harbor',
        targetLocationId: 'loc-new',
        avatarUrl: _locationImageUrl,
        tickCount: 3,
        contextLabel: 'Azure Coast',
      ),
      WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char-new',
        name: 'New Wanderer',
        targetLocationId: 'loc-new',
        avatarUrl: _characterAvatarUrl,
        tickCount: 3,
        contextLabel: 'Wandering swordsman',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              WorldUpdatePushBannerQueue(
                top: 12,
                revision: 1,
                notices: notices,
                displayDuration: Duration(milliseconds: 50),
                transitionDuration: Duration(milliseconds: 20),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('New location available'), findsOneWidget);
    expect(find.text('New Harbor · Azure Coast'), findsOneWidget);
    expect(find.text('New Wanderer · Wandering swordsman'), findsNothing);
    final locationImage = tester.widget<GenesisStaticNetworkImage>(
      find.byType(GenesisStaticNetworkImage),
    );
    expect(locationImage.imageUrl, _locationImageUrl);
    final locationImageClip = tester.widget<ClipRRect>(
      find.byKey(const ValueKey<String>('world-update-push-location-image')),
    );
    expect(locationImageClip.borderRadius, BorderRadius.circular(10));
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('world-update-push-location-image')),
      ),
      const Size.square(48),
    );
    expect(
      find.byKey(const ValueKey<String>('world-update-push-character-avatar')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('New Harbor · Azure Coast'), findsOneWidget);
    expect(find.text('New Wanderer · Wandering swordsman'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('New Harbor · Azure Coast'), findsOneWidget);
    expect(find.text('New Wanderer · Wandering swordsman'), findsNothing);

    await tester.pump(const Duration(milliseconds: 11));

    expect(find.text('New Wanderer · Wandering swordsman'), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('New Harbor · Azure Coast'), findsNothing);
    expect(find.text('New character joined'), findsOneWidget);
    expect(find.text('New Wanderer · Wandering swordsman'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('world-update-push-location-icon')),
      findsNothing,
    );
    final characterAvatar = tester.widget<GenesisCharacterAvatar>(
      find.byKey(const ValueKey<String>('world-update-push-character-avatar')),
    );
    expect(characterAvatar.url, _characterAvatarUrl);
    expect(characterAvatar.name, 'New Wanderer');
    expect(characterAvatar.size, 48);
    expect(characterAvatar.borderRadius, 24);
    final detailText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-update-push-detail')),
    );
    expect(detailText.style?.fontSize, 13);
    expect(detailText.style?.color, const Color(0xF2FFFFFF));
    expect(detailText.maxLines, 1);
    expect(detailText.overflow, TextOverflow.ellipsis);
    final detailSpan = detailText.textSpan! as TextSpan;
    expect(detailSpan.text, 'New Wanderer');
    final identitySpan = detailSpan.children!.single as TextSpan;
    expect(identitySpan.text, ' · Wandering swordsman');
    expect(identitySpan.style?.fontSize, 11);
    expect(identitySpan.style?.fontWeight, FontWeight.w500);
    expect(identitySpan.style?.color, const Color(0xB8FFFFFF));
    final bannerRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-update-push-banner')),
    );
    final avatarRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-update-push-character-avatar')),
    );
    expect(avatarRect.size, const Size.square(48));
    expect(avatarRect.left - bannerRect.left, 8);
    expect(avatarRect.top - bannerRect.top, 8);
    expect(bannerRect.bottom - avatarRect.bottom, 8);
    expect(bannerRect.height, 64);
    final detailRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-update-push-detail')),
    );
    final categoryRect = tester.getRect(find.text('New character joined'));
    expect(detailRect.top - categoryRect.bottom, closeTo(5, 0.01));
    expect(detailRect.left - avatarRect.right, 10);

    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('world-update-push-banner')),
      findsNothing,
    );
  });

  testWidgets('world update push omits separator without context', (
    WidgetTester tester,
  ) async {
    Future<void> pumpNotice(WorldContentUpdateNotice notice) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                WorldUpdatePushBannerQueue(
                  key: ValueKey<String>(notice.entityId),
                  top: 12,
                  revision: 1,
                  notices: [notice],
                  displayDuration: const Duration(hours: 1),
                  transitionDuration: Duration.zero,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpNotice(
      const WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.location,
        entityId: 'location-without-parent',
        name: 'Root Harbor',
        targetLocationId: 'location-without-parent',
        avatarUrl: '',
        tickCount: 1,
      ),
    );

    expect(find.text('New location available'), findsOneWidget);
    expect(find.text('Root Harbor'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
    expect(find.byType(GenesisStaticNetworkImage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('world-update-push-location-icon')),
      findsOneWidget,
    );
    final locationFallback = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('world-update-push-location-icon')),
    );
    final locationFallbackDecoration =
        locationFallback.decoration as BoxDecoration;
    expect(locationFallbackDecoration.shape, BoxShape.rectangle);
    expect(locationFallbackDecoration.borderRadius, BorderRadius.circular(10));

    await pumpNotice(
      const WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.character,
        entityId: 'character-without-identity',
        name: 'Nameless Wanderer',
        targetLocationId: 'location-without-parent',
        avatarUrl: '',
        tickCount: 1,
        contextLabel: '   ',
      ),
    );

    expect(find.text('New character joined'), findsOneWidget);
    expect(find.text('Nameless Wanderer'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('location image failure falls back to the location icon', (
    WidgetTester tester,
  ) async {
    debugGenesisStaticNetworkImageCompleter = (_) =>
        OneFrameImageStreamCompleter(
          Future<ImageInfo>.error(StateError('location image failed')),
        );
    addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              WorldUpdatePushBannerQueue(
                top: 12,
                revision: 1,
                notices: [
                  WorldContentUpdateNotice(
                    kind: WorldContentUpdateKind.location,
                    entityId: 'location-with-failed-image',
                    name: 'Storm Harbor',
                    targetLocationId: 'location-with-failed-image',
                    avatarUrl: _locationImageUrl,
                    tickCount: 1,
                  ),
                ],
                displayDuration: Duration(hours: 1),
                transitionDuration: Duration.zero,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(GenesisStaticNetworkImage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('world-update-push-location-icon')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('world update push enters from above', (
    WidgetTester tester,
  ) async {
    const bannerKey = ValueKey<String>('world-update-push-banner');
    const transitionDuration = Duration(milliseconds: 200);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              WorldUpdatePushBannerQueue(
                top: 60,
                revision: 1,
                notices: [
                  WorldContentUpdateNotice(
                    kind: WorldContentUpdateKind.location,
                    entityId: 'loc-new',
                    name: 'New Harbor',
                    targetLocationId: 'loc-new',
                    avatarUrl: '',
                    tickCount: 3,
                  ),
                ],
                displayDuration: Duration(hours: 1),
                transitionDuration: transitionDuration,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(bannerKey), findsNothing);

    await tester.pump();
    final startingTop = tester.getTopLeft(find.byKey(bannerKey)).dy;

    await tester.pump(transitionDuration ~/ 2);
    final middleTop = tester.getTopLeft(find.byKey(bannerKey)).dy;

    await tester.pump(transitionDuration ~/ 2);
    final settledTop = tester.getTopLeft(find.byKey(bannerKey)).dy;

    expect(startingTop, lessThan(middleTop));
    expect(middleTop, lessThan(settledTop));
    expect(settledTop, closeTo(60, 0.01));
  });

  testWidgets('notices received during exit wait for the prior banner', (
    WidgetTester tester,
  ) async {
    var revision = 0;
    var notices = const <WorldContentUpdateNotice>[];
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Stack(
                children: [
                  WorldUpdatePushBannerQueue(
                    top: 12,
                    revision: revision,
                    notices: notices,
                    displayDuration: const Duration(milliseconds: 50),
                    transitionDuration: const Duration(milliseconds: 20),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    updateHost(() {
      revision = 1;
      notices = const [
        WorldContentUpdateNotice(
          kind: WorldContentUpdateKind.location,
          entityId: 'loc-new',
          name: 'New Harbor',
          targetLocationId: 'loc-new',
          avatarUrl: '',
          tickCount: 3,
        ),
      ];
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('New Harbor'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 10));

    updateHost(() {
      revision = 2;
      notices = const [
        WorldContentUpdateNotice(
          kind: WorldContentUpdateKind.character,
          entityId: 'char-new',
          name: 'New Wanderer',
          targetLocationId: 'loc-new',
          avatarUrl: '',
          tickCount: 3,
        ),
      ];
    });
    await tester.pump();

    expect(find.text('New Harbor'), findsOneWidget);
    expect(find.text('New Wanderer'), findsNothing);

    await tester.pump(const Duration(milliseconds: 11));

    expect(find.text('New Wanderer'), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('New Harbor'), findsNothing);
    expect(find.text('New Wanderer'), findsOneWidget);
  });
}

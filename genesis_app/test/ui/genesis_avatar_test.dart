import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_avatar_radii.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  test('initialsForAvatarName follows Chinese and foreign name rules', () {
    expect(initialsForAvatarName('张三'), '张');
    expect(initialsForAvatarName('李七七'), '七七');
    expect(initialsForAvatarName('Tom Lee'), 'TL');
    expect(initialsForAvatarName('Tom'), 'T');
    expect(initialsForAvatarName(''), '?');
  });

  test('avatarColorForName is stable per name', () {
    expect(avatarColorForName('Tom Lee'), avatarColorForName('Tom Lee'));
    expect(avatarColorForName('李七七'), avatarColorForName('李七七'));
  });

  testWidgets('GenesisAvatar renders generated fallback for empty URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisAvatar(url: '', name: 'Tom Lee', size: 40),
        ),
      ),
    );

    expect(find.text('TL'), findsOneWidget);
  });

  testWidgets('avatar components use shared default radius tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GenesisAvatar(url: '', name: 'Tom Lee', size: 40),
              GenesisCharacterAvatar(url: '', name: 'Iris', size: 40),
            ],
          ),
        ),
      ),
    );

    final userAvatar = tester.widget<GenesisAvatar>(
      find.byType(GenesisAvatar).first,
    );
    final characterAvatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );

    expect(userAvatar.borderRadius, GenesisAvatarRadii.user);
    expect(characterAvatar.borderRadius, GenesisAvatarRadii.character);
  });

  testWidgets('GenesisAvatar crops loaded images from the top center', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisAvatar(
            url: 'assets/images/default_list_image.png',
            name: 'Iris',
            width: 40,
            height: 60,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.image(const AssetImage('assets/images/default_list_image.png')),
    );
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
    expect(tester.getSize(find.byType(GenesisAvatar)), const Size(40, 60));
  });

  testWidgets('GenesisAvatar builds xl resize URL from display width', (
    tester,
  ) async {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        smUrl: 'https://cdn.example.com/avatar_400_300.webp',
        xlUrl: 'https://cdn.example.com/avatar_800_600.webp',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Scaffold(
            body: GenesisAvatar(
              url: resource.displayUrl,
              name: 'Iris',
              width: 300,
              height: 225,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      image.imageUrl,
      'https://cdn.example.com/avatar_800_600.webp'
      '?x-oss-process=image/resize,w_720,image/format,webp',
    );
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.placeholderFadeInDuration, Duration.zero);
  });

  testWidgets('GenesisAvatar can hide fallback while network image loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisAvatar(
            url: 'https://cdn.example.com/avatar.webp',
            name: 'Tom Lee',
            size: 40,
            showFallbackWhileLoading: false,
          ),
        ),
      ),
    );

    expect(find.text('TL'), findsNothing);
  });

  testWidgets(
    'GenesisCharacterAvatar keeps decorations while network image loads',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenesisCharacterAvatar(
              url: 'https://cdn.example.com/character.webp',
              name: 'Iris',
              size: 40,
              showStar: true,
              showFallbackWhileLoading: false,
              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 4)],
              border: Border.all(color: Colors.red, width: 1),
            ),
          ),
        ),
      );

      expect(find.text('I'), findsNothing);
      expect(find.byIcon(MyFlutterApp.redstarCharIcon), findsOneWidget);

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final avatarDecoration = decoratedBoxes
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .singleWhere((decoration) => decoration.border != null);
      final shadowDecoration = decoratedBoxes
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .singleWhere((decoration) => decoration.boxShadow != null);
      final borderOverlay = find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border != null,
        ),
        matching: find.byType(Positioned),
      );

      expect(avatarDecoration.border, isNotNull);
      expect(shadowDecoration.boxShadow, isNotEmpty);
      expect(borderOverlay, findsOneWidget);
    },
  );

  testWidgets('GenesisAvatar can hide fallback when image is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisAvatar(
            url: '',
            name: 'Tom Lee',
            size: 40,
            showFallbackWhenUnavailable: false,
          ),
        ),
      ),
    );

    expect(find.text('TL'), findsNothing);
  });
}

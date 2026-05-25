import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_v1_data.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('mock world data includes dense map points and local avatar assets', () {
    expect(kMockV1Locations.length, greaterThanOrEqualTo(5));

    final countsByLocation = <String, int>{};
    for (final character in kMockV1Characters) {
      final locationId = '${character['location_id']}';
      countsByLocation[locationId] = (countsByLocation[locationId] ?? 0) + 1;
    }

    expect(countsByLocation['loc_hub'], 3);
    expect(countsByLocation['loc_gate'], greaterThanOrEqualTo(4));
    expect(countsByLocation['loc_market'], greaterThanOrEqualTo(5));
    expect(
      File(kMockV1SteamMapImage).existsSync(),
      isTrue,
      reason: kMockV1SteamMapImage,
    );
    for (final origin in kMockV1Origins) {
      expect(origin['cover'], kMockV1SteamMapImage);
    }
    for (final world in kMockV1Worlds) {
      expect(world['cover'], kMockV1SteamMapImage);
    }

    final avatarPaths = kMockV1Characters
        .map((character) => '${character['avatar']}')
        .where((path) => path.startsWith('assets/images/mock_avatars/'))
        .toSet();
    expect(avatarPaths.length, greaterThanOrEqualTo(8));
    for (final path in avatarPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('world map lays out fewer than four avatars in one row', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/mock_avatars/avatar_iris.png',
          showStar: true,
        ),
        UserAvatar(
          'BB',
          name: 'Bert',
          avatarUrl: 'assets/images/mock_avatars/avatar_crow.png',
        ),
        UserAvatar(
          'CC',
          name: 'Cy',
          avatarUrl: 'assets/images/mock_avatars/avatar_lena.png',
        ),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(3));
    expect(tester.getSize(avatars.first), const Size(42, 42));
    expect(
      tester.widget<GenesisCharacterAvatar>(avatars.first).boxShadow,
      isNotEmpty,
    );
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    final first = tester.getTopLeft(avatars.at(0));
    final second = tester.getTopLeft(avatars.at(1));
    final third = tester.getTopLeft(avatars.at(2));
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, greaterThan(second.dx));
  });

  testWidgets('world map renders local asset map background', (tester) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kMockV1SteamMapImage,
      users: const [],
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == kMockV1SteamMapImage,
      ),
      findsOneWidget,
    );
  });

  testWidgets('world map lays out four avatars in a two by two grid', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/mock_avatars/avatar_iris.png',
        ),
        UserAvatar(
          'BB',
          name: 'Bert',
          avatarUrl: 'assets/images/mock_avatars/avatar_crow.png',
        ),
        UserAvatar(
          'CC',
          name: 'Cy',
          avatarUrl: 'assets/images/mock_avatars/avatar_lena.png',
        ),
        UserAvatar(
          'DD',
          name: 'Dee',
          avatarUrl: 'assets/images/mock_avatars/avatar_orren.png',
        ),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(4));

    final topLeftAvatar = tester.getTopLeft(avatars.at(0));
    final topRightAvatar = tester.getTopLeft(avatars.at(1));
    final bottomLeftAvatar = tester.getTopLeft(avatars.at(2));
    final bottomRightAvatar = tester.getTopLeft(avatars.at(3));
    final pointY = _mapSize.height * _pointPosition.dy;

    expect(topLeftAvatar.dy, closeTo(pointY + 10, 0.01));
    expect(topRightAvatar.dy, topLeftAvatar.dy);
    expect(bottomLeftAvatar.dy, greaterThan(topLeftAvatar.dy));
    expect(bottomRightAvatar.dy, bottomLeftAvatar.dy);
    expect(topRightAvatar.dx, greaterThan(topLeftAvatar.dx));
    expect(bottomLeftAvatar.dx, topLeftAvatar.dx);
    expect(bottomRightAvatar.dx, topRightAvatar.dx);
  });

  testWidgets('world map allows slight avatar overlap for dense rings', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [
        UserAvatar('AA', name: 'Ada'),
        UserAvatar('BB', name: 'Bert'),
        UserAvatar('CC', name: 'Cy'),
        UserAvatar('DD', name: 'Dee'),
        UserAvatar('EE', name: 'Eli'),
        UserAvatar('FF', name: 'Flo'),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(6));

    final firstCenter = tester.getCenter(avatars.at(0));
    final secondCenter = tester.getCenter(avatars.at(1));
    expect((firstCenter - secondCenter).distance, lessThan(42));
  });
}

const _mapSize = Size(375, 670);
const _pointPosition = Offset(0.5, 0.35);

Future<void> _pumpWorldMap(
  WidgetTester tester, {
  required List<UserAvatar> users,
  String mapImageUrl = '',
}) async {
  tester.view.physicalSize = const Size(430, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _mapSize.width,
            height: _mapSize.height,
            child: WorldMap(
              mapImageUrl: mapImageUrl,
              points: [
                WorldPoint(
                  id: 'point-1',
                  name: 'Gate',
                  type: WorldPointType.portal,
                  position: _pointPosition,
                  users: users,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

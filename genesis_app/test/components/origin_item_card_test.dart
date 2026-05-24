import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_card.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

void main() {
  testWidgets('renders image stats on the cover overlay', (
    WidgetTester tester,
  ) async {
    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      name: 'Alpha Empire',
      cover: '',
      displaySubtitle: 'Tycoon idols',
      worldView: '',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>[],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 0,
      characterCnt: 0,
      locationCnt: 0,
      coverHeight: 260,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, child: OriginItemCard(item: item)),
        ),
      ),
    );

    expect(find.byIcon(MyFlutterApp.save), findsOneWidget);
    expect(find.byIcon(MyFlutterApp.copy), findsOneWidget);
    expect(find.text('2.3K'), findsOneWidget);
    expect(find.text('4.4M'), findsOneWidget);
    expect(find.text('v3'), findsNothing);
  });
}

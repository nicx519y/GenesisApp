import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/popular_origin_list.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_card.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

void main() {
  testWidgets('renders popular origin feed fields and handles taps', (
    WidgetTester tester,
  ) async {
    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      name: 'Alpha Empire',
      cover: '',
      displaySubtitle: 'Tycoon idols compete for the crown.',
      worldView: 'A city powered by celebrity markets.',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>['romance', 'tycoon'],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 128,
      characterCnt: 6,
      locationCnt: 3,
      coverHeight: 260,
    );
    var tappedOid = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PopularOriginList(
              items: const <OriginListItem>[item],
              onItemTap: (item) => tappedOid = item.oid,
            ),
          ),
        ),
      ),
    );

    expect(find.text('#Alpha Empire'), findsWidgets);
    expect(find.text('Copy World Progress'), findsOneWidget);
    expect(find.text('OID: o_alpha'), findsOneWidget);
    expect(find.text('v3'), findsOneWidget);
    expect(find.text('Discuss (128)'), findsOneWidget);
    expect(find.text('Tags: romance, tycoon'), findsOneWidget);
    expect(find.byIcon(MyFlutterApp.save), findsOneWidget);
    expect(find.byIcon(MyFlutterApp.copy), findsOneWidget);
    expect(find.text('2.3K'), findsOneWidget);
    expect(find.text('4.4M'), findsOneWidget);

    await tester.tap(find.text('Copy World Progress'));
    expect(tappedOid, 'o_alpha');
  });
}

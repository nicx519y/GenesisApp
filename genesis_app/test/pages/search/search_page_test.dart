import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/origin/stat_item.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/pages/search/search_page.dart';
import 'package:genesis_flutter_android/pages/world/world_page_result.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_origin_card_geometry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('does not request search before three letters or chinese chars', (
    tester,
  ) async {
    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 700));

    expect(transport.searchRequests, isEmpty);

    await tester.enterText(find.byType(TextField), '1你');
    await tester.pump(const Duration(milliseconds: 700));

    expect(transport.searchRequests, isEmpty);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));

    expect(transport.searchRequests, isEmpty);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(transport.searchRequests, hasLength(1));
    expect(
      transport.searchRequests.single.uri.queryParameters['keyword'],
      'abc',
    );
    expect(
      transport.searchRequests.single.uri.queryParameters['type'],
      'origin',
    );
  });

  testWidgets('uses card skeletons instead of progress rings while loading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(
      searchDelay: const Duration(seconds: 1),
    );
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('genesis-search-result-list-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'genesis-search-result-origin-thumbnail-skeleton',
        ),
      ),
      findsWidgets,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('#Origin 1'), findsOneWidget);
  });

  testWidgets('shows no results only after a successful empty response', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(
      singleWorldResult: true,
      searchDelay: const Duration(seconds: 1),
    );
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('No results.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('genesis-search-result-list-skeleton')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('switches directly from results to the next tab skeleton', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(
      searchDelay: const Duration(seconds: 1),
    );
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('#Origin 1'), findsOneWidget);

    await tester.tap(find.text('World'));
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (transport.searchRequests.any(
        (request) => request.uri.queryParameters['type'] == 'world',
      )) {
        break;
      }
    }
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'world');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No results.'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>(
          'genesis-search-result-world-thumbnail-skeleton',
        ),
      ),
      findsWidgets,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('World 1'), findsOneWidget);
    expect(find.text('Tick 11 · 21 Messages · 41 Players'), findsOneWidget);
  });

  testWidgets('uses the shared list progress style while loading next page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(
      paginated: true,
      loadMoreDelay: const Duration(seconds: 1),
    );
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final resultsList = find.byType(ListView).hitTestable().first;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: resultsList, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('search-result-load-more')),
      findsOneWidget,
    );
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.strokeWidth, 2);
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(20),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('#Origin 21'), findsOneWidget);
  });

  testWidgets('updates all tab totals from every typed response', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(
      sectionTotals: const {'origin': 14, 'world': 24, 'user': 34},
    );
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    final tabRectsBeforeTotals = {
      for (final tab in const ['origin', 'world', 'user'])
        tab: tester.getRect(find.byKey(ValueKey<String>('search-tab-$tab'))),
    };
    expect(tabRectsBeforeTotals['origin']?.left, 16);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    for (final entry in tabRectsBeforeTotals.entries) {
      expect(
        tester.getRect(find.byKey(ValueKey<String>('search-tab-${entry.key}'))),
        entry.value,
      );
    }
    expect(_searchTabCount('origin', '14'), findsOneWidget);
    expect(_searchTabCount('world', '24'), findsOneWidget);
    expect(_searchTabCount('user', '34'), findsOneWidget);
    final originCount = tester.widget<Text>(_searchTabCount('origin', '14'));
    expect(originCount.style?.fontSize, 10);
    expect(originCount.style?.color, const Color(0xFFFF2442));
    expect(find.text('All'), findsNothing);
    expect(find.text('#Origin 4'), findsOneWidget);
    expect(
      transport.searchRequests.single.uri.queryParameters['type'],
      'origin',
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();
    expect(_searchTabCount('origin', '14'), findsOneWidget);
    expect(_searchTabCount('world', '24'), findsOneWidget);
    expect(_searchTabCount('user', '34'), findsOneWidget);
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'world');

    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();
    expect(_searchTabCount('origin', '14'), findsOneWidget);
    expect(_searchTabCount('world', '24'), findsOneWidget);
    expect(_searchTabCount('user', '34'), findsOneWidget);
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'user');
    expect(transport.searchRequests, hasLength(3));
  });

  testWidgets('selects the default tab from the case-insensitive id prefix', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'U_test');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('#Origin 1'), findsNothing);
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'user');

    await tester.enterText(find.byType(TextField), 'w_TEST');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('World 1'), findsOneWidget);
    expect(find.text('User 1'), findsNothing);
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'world');

    await tester.enterText(find.byType(TextField), 'anything');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('#Origin 1'), findsOneWidget);
    expect(find.text('World 1'), findsNothing);
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'origin');
  });

  testWidgets('loads the next page independently for all three typed tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(paginated: true);
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    for (final entry in const [
      (tabLabel: 'Worldo', type: 'origin', lastItem: '#Origin 21'),
      (tabLabel: 'World', type: 'world', lastItem: 'World 21'),
      (tabLabel: 'User', type: 'user', lastItem: 'User 21'),
    ]) {
      if (entry.type != 'origin') {
        await tester.tap(find.text(entry.tabLabel));
        await tester.pumpAndSettle();
      }

      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      final requests = transport.searchRequests
          .where((request) => request.uri.queryParameters['type'] == entry.type)
          .toList(growable: false);
      expect(requests, hasLength(2));
      expect(requests.last.uri.queryParameters['pn'], '2');
      expect(requests.last.uri.queryParameters['rn'], '20');
      expect(find.text(entry.lastItem), findsOneWidget);
    }
  });

  testWidgets('only shows optional Worldo metadata selected by matches', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(originNameMatchOnly: true);
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('#Origin 1'), findsOneWidget);
    expect(find.textContaining('Brief:'), findsNothing);
    expect(find.textContaining('Characters:'), findsNothing);
    expect(find.textContaining('Latest Version: V1'), findsOneWidget);
  });

  testWidgets('renders world fields from the v2 search contract', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    expect(find.text('World 1'), findsOneWidget);
    expect(find.textContaining('WID: world_1'), findsOneWidget);
    expect(find.textContaining('Owner: Owner 1'), findsOneWidget);
    expect(find.text('Tick 11 · 21 Messages · 41 Players'), findsOneWidget);
  });

  testWidgets('shows a highlighted Tags row only for matched tags', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(includeTagMatches: true);
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'tag');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final originTags = tester.widget<Text>(find.text('Tags: tag-1'));
    expect(_highlightedTextParts(originTags), ['tag']);
    expect(
      tester.getTopLeft(find.text('Tags: tag-1')).dy,
      lessThan(tester.getTopLeft(find.text('Latest Version: V1')).dy),
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    final worldTags = tester.widget<Text>(find.text('Tags: world-tag-1'));
    expect(_highlightedTextParts(worldTags), ['tag']);
    expect(
      tester.getTopLeft(find.text('Tags: world-tag-1')).dy,
      greaterThan(tester.getTopLeft(find.textContaining('WID: world_1')).dy),
    );
  });

  testWidgets('does not show a Tags row without a tag match', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tags:'), findsNothing);

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tags:'), findsNothing);
  });

  testWidgets('shows the origin version returned by v2 search', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final brief = tester.widget<Text>(
      find.textContaining('Brief: Origin brief 1'),
    );
    expect(brief.textSpan?.toPlainText(), 'Brief: Origin brief 1');
    expect(brief.maxLines, 2);
    expect(brief.textSpan?.toPlainText(), isNot(contains('…')));
    expect(
      find.textContaining('Characters: Character 1, Supporting 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Latest Version: V1'), findsOneWidget);
  });

  testWidgets('keeps a prefix before a complete trailing Brief match', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(trailingBriefMatch: true);
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'rooftop');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final briefFinder = find.textContaining('Brief:');
    final brief = tester.widget<Text>(briefFinder.first);
    final displayedBrief = brief.textSpan!.toPlainText();
    expect(brief.maxLines, 2);
    expect(displayedBrief, contains('…'));
    expect(displayedBrief, startsWith('Brief: Two'));
    expect(displayedBrief, isNot(startsWith('Brief: …')));
    expect(displayedBrief, contains('rooftop'));
    expect(displayedBrief, endsWith('rooftop'));
    expect(_highlightedTextParts(brief), contains('rooftop'));
    expect(displayedBrief, isNot(contains('ro…')));

    final painter = TextPainter(
      text: TextSpan(style: brief.style, children: [brief.textSpan!]),
      maxLines: 2,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tester.getSize(briefFinder.first).width);
    expect(painter.didExceedMaxLines, isFalse);
  });

  testWidgets('highlights every documented v2 search match field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(_highlightedTextParts(tester.widget<Text>(find.text('#Origin 1'))), [
      'Origin',
    ]);
    expect(
      _highlightedTextParts(
        tester.widget<Text>(find.textContaining('Brief: Origin brief 1')),
      ),
      ['Origin', 'brief'],
    );
    expect(
      _highlightedTextParts(
        tester.widget<Text>(
          find.textContaining('Characters: Character 1, Supporting 1'),
        ),
      ),
      ['Character', 'Supporting'],
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();
    expect(_highlightedTextParts(tester.widget<Text>(find.text('World 1'))), [
      'World',
    ]);

    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();
    expect(_highlightedTextParts(tester.widget<Text>(find.text('User 1'))), [
      'User',
    ]);
  });

  testWidgets('shows the documented origin owner name in search results', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('Originator: Deleted User'), findsOneWidget);
  });

  testWidgets('dismisses search focus when tapping result area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(400, 1100));
    await tester.pump();

    expect(editable.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('uses the Worldo cover ratio and compact result spacing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final originTile = find
        .ancestor(
          of: find.text('#Origin 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final originImage = tester.widget<GenesisListImage>(
      find.descendant(of: originTile, matching: find.byType(GenesisListImage)),
    );
    expect(originImage.width, 60);
    expect(originImage.height, 60 / genesisOriginCoverAspectRatio);

    final originSizedBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(of: originTile, matching: find.byType(SizedBox)),
        )
        .toList();
    expect(
      originSizedBoxes.any((box) => box.width == 10),
      isTrue,
      reason: 'Origin image-to-text gap should match Me collection rows.',
    );
    expect(
      originSizedBoxes.any((box) => box.height == 5),
      isTrue,
      reason: 'Origin title-to-subtitle gap should match Me collection rows.',
    );
    expect(
      originSizedBoxes.any((box) => box.height == 8),
      isTrue,
      reason: 'Origin subtitle-to-stats gap should match Me collection rows.',
    );
    final originSubtitle = tester.widget<Text>(
      find.descendant(
        of: originTile,
        matching: find.textContaining('Latest Version'),
      ),
    );
    expect(originSubtitle.style?.height, 1.3);

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    final worldTile = find
        .ancestor(
          of: find.text('World 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final worldImage = tester.widget<GenesisListImage>(
      find.descendant(of: worldTile, matching: find.byType(GenesisListImage)),
    );
    expect(worldImage.width, 60);
    expect(worldImage.height, 60);

    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();

    final userTile = find
        .ancestor(
          of: find.text('User 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final userAvatar = tester.widget<GenesisAvatar>(
      find.descendant(of: userTile, matching: find.byType(GenesisAvatar)),
    );
    expect(userAvatar.size, 60);
    expect(userAvatar.borderRadius, 30);

    final userAvatarRect = tester.getRect(
      find.descendant(of: userTile, matching: find.byType(GenesisAvatar)),
    );
    final userNameRect = tester.getRect(
      find.descendant(of: userTile, matching: find.text('User 1')),
    );
    final userIdRect = tester.getRect(
      find.descendant(of: userTile, matching: find.textContaining('UID:')),
    );
    expect(
      (userNameRect.top + userIdRect.bottom) / 2,
      closeTo(userAvatarRect.center.dy, 1),
    );

    final userSizedBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(of: userTile, matching: find.byType(SizedBox)),
        )
        .toList();
    expect(userSizedBoxes.any((box) => box.width == 10), isTrue);
    expect(userSizedBoxes.any((box) => box.height == 7), isTrue);
  });

  testWidgets('uses the full screen DPR for every search result image', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1290, 4200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final listImages = tester.widgetList<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(listImages, isNotEmpty);
    expect(listImages.every((image) => image.maxDevicePixelRatio == 3), isTrue);

    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();
    final userAvatars = tester.widgetList<GenesisAvatar>(
      find.byType(GenesisAvatar),
    );
    expect(userAvatars, isNotEmpty);
    expect(
      userAvatars.every((avatar) => avatar.maxDevicePixelRatio == 3),
      isTrue,
    );
  });

  testWidgets('Worldo keeps matched character names whole within two lines', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport(longOriginContent: true);
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final tile = find
        .ancestor(
          of: find.text('#Origin 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final brief = tester.widget<Text>(find.textContaining('Brief:'));
    final characters = find.textContaining('Characters:');
    final charactersText = tester.widget<Text>(characters);
    final charactersValue = charactersText.textSpan!.toPlainText();
    final displayedCharacterTokens = charactersValue
        .replaceFirst('Characters: ', '')
        .split(', ');
    final latestVersion = find.textContaining('Latest Version: V1');

    expect(brief.maxLines, 2);
    expect(brief.textSpan?.toPlainText(), contains('…'));
    expect(brief.textSpan?.toPlainText(), contains('Latest Version visible'));
    expect(_highlightedTextParts(brief), contains('Latest Version visible'));
    expect(characters, findsOneWidget);
    expect(charactersText.maxLines, 2);
    expect(charactersValue, contains('…'));
    expect(charactersValue, isNot(startsWith('Characters: …')));
    expect(charactersValue, contains('Character 1'));
    expect(charactersValue, contains('Extra Character 12'));
    expect(
      _highlightedTextParts(charactersText),
      contains('Extra Character 12'),
    );
    expect(
      displayedCharacterTokens.where((token) => token != '…'),
      everyElement(
        isIn(const [
          'Character 1',
          'Supporting 1',
          'Extra Character 3',
          'Extra Character 4',
          'Extra Character 5',
          'Extra Character 6',
          'Extra Character 7',
          'Extra Character 8',
          'Extra Character 9',
          'Extra Character 10',
          'Extra Character 11',
          'Extra Character 12',
        ]),
      ),
    );
    final charactersPainter =
        TextPainter(
          text: TextSpan(
            style: charactersText.style,
            children: [charactersText.textSpan!],
          ),
          maxLines: 2,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(
          maxWidth: tester
              .renderObject<RenderBox>(characters)
              .constraints
              .maxWidth,
        );
    expect(charactersPainter.didExceedMaxLines, isFalse);
    expect(latestVersion, findsOneWidget);
    expect(tester.getSize(tile).height, greaterThan(120));
    expect(
      tester.getTopLeft(latestVersion).dy,
      greaterThan(tester.getTopLeft(characters).dy),
    );
    expect(
      tester.getBottomRight(latestVersion).dy,
      lessThanOrEqualTo(tester.getBottomRight(tile).dy),
    );
  });

  testWidgets('removes deleted world from search results after detail closes', (
    tester,
  ) async {
    final transport = _SearchPageTransport(singleWorldResult: true);
    await _pumpSearchPage(
      tester,
      transport,
      onGenerateRoute: (settings) {
        if (settings.name != RouteNames.world) return null;
        return MaterialPageRoute<WorldPageResult>(
          settings: settings,
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const WorldPageResult.deleted(deletedWorldId: 'world_1')),
                child: const Text('Delete world'),
              ),
            ),
          ),
        );
      },
    );

    await tester.enterText(find.byType(TextField), 'w_test');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('World 1'), findsOneWidget);
    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete world'));
    await tester.pumpAndSettle();

    expect(find.text('World 1'), findsNothing);
    expect(find.text('No results.'), findsOneWidget);
  });
}

Finder _searchTabCount(String tab, String count) {
  return find.descendant(
    of: find.byKey(ValueKey<String>('search-tab-count-$tab')),
    matching: find.text(count),
  );
}

Future<void> _pumpSearchPage(
  WidgetTester tester,
  _SearchPageTransport transport, {
  RouteFactory? onGenerateRoute,
}) async {
  await tester.pumpWidget(
    AppServicesScope(
      services: await _servicesWithTransport(transport),
      child: MaterialApp(
        home: const SearchPage(),
        onGenerateRoute: onGenerateRoute,
      ),
    ),
  );
  await tester.pump();
}

Future<AppServices> _servicesWithTransport(
  _SearchPageTransport transport,
) async {
  final base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: transport,
  );
  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: transport,
  );
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_test');
  await sessionStore.saveAuthToken('test-token');
  final api = GenesisApi(
    apiClient: apiClient,
    healthClient: healthClient,
    sessionStore: sessionStore,
  );
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: api,
    chatroom: base.chatroom,
    chatroomMessages: MemoryChatroomMessageStorage(),
    directMessageConversations: DirectMessageConversationStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageConversationStorage(),
    ),
    directMessageMessages: DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageMessageStorage(),
    ),
    appVersionCheck: base.appVersionCheck,
    externalUrlOpener: base.externalUrlOpener,
  );
}

class _SearchPageTransport implements HttpTransport {
  _SearchPageTransport({
    this.singleWorldResult = false,
    this.longOriginContent = false,
    this.originNameMatchOnly = false,
    this.trailingBriefMatch = false,
    this.includeTagMatches = false,
    this.paginated = false,
    this.sectionTotals = const <String, int>{},
    this.searchDelay = Duration.zero,
    this.loadMoreDelay = Duration.zero,
  });

  final bool singleWorldResult;
  final bool longOriginContent;
  final bool originNameMatchOnly;
  final bool trailingBriefMatch;
  final bool includeTagMatches;
  final bool paginated;
  final Map<String, int> sectionTotals;
  final Duration searchDelay;
  final Duration loadMoreDelay;
  final List<TransportRequest> requests = <TransportRequest>[];

  List<TransportRequest> get searchRequests => requests
      .where((request) => request.uri.path.endsWith('/v2/search'))
      .toList(growable: false);

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/v2/search')) {
      final pageNumber =
          int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
      final delay = pageNumber > 1 ? loadMoreDelay : searchDelay;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (singleWorldResult) {
        return _jsonResponse({
          'keyword': request.uri.queryParameters['keyword'] ?? '',
          'type': request.uri.queryParameters['type'] ?? '',
          'origins': _emptySection(),
          'worlds': {
            'list': [_item('world', 1)],
            'total': 1,
            'pn': 1,
            'rn': 20,
          },
          'users': _emptySection(),
        });
      }
      return _jsonResponse({
        'keyword': request.uri.queryParameters['keyword'] ?? '',
        'type': request.uri.queryParameters['type'] ?? '',
        'origins': _section(
          'origin',
          request.uri.queryParameters['type'],
          total: sectionTotals['origin'],
          longOriginContent: longOriginContent,
          originNameMatchOnly: originNameMatchOnly,
          trailingBriefMatch: trailingBriefMatch,
          includeTagMatches: includeTagMatches,
          paginated: paginated,
          pageNumber: pageNumber,
        ),
        'worlds': _section(
          'world',
          request.uri.queryParameters['type'],
          total: sectionTotals['world'],
          includeTagMatches: includeTagMatches,
          paginated: paginated,
          pageNumber: pageNumber,
        ),
        'users': _section(
          'user',
          request.uri.queryParameters['type'],
          total: sectionTotals['user'],
          paginated: paginated,
          pageNumber: pageNumber,
        ),
      });
    }
    return _jsonResponse(const <String, dynamic>{});
  }
}

Map<String, dynamic> _emptySection() {
  return const {'list': <Object?>[], 'total': 0, 'pn': 1, 'rn': 20};
}

Map<String, dynamic> _section(
  String type,
  String? requestedType, {
  int? total,
  bool longOriginContent = false,
  bool originNameMatchOnly = false,
  bool trailingBriefMatch = false,
  bool includeTagMatches = false,
  bool paginated = false,
  int pageNumber = 1,
}) {
  final resultTotal = total ?? (paginated ? 21 : 4);
  if (requestedType != null &&
      requestedType.isNotEmpty &&
      requestedType != type) {
    return {
      'list': const <Object?>[],
      'total': resultTotal,
      'pn': pageNumber,
      'rn': 20,
    };
  }
  final itemCount = paginated
      ? switch (pageNumber) {
          1 => 20,
          2 => 1,
          _ => 0,
        }
      : longOriginContent && type == 'origin'
      ? 1
      : 4;
  final firstItemIndex = paginated ? ((pageNumber - 1) * 20) + 1 : 1;
  return {
    'list': [
      for (var offset = 0; offset < itemCount; offset += 1)
        _item(
          type,
          firstItemIndex + offset,
          longOriginContent: longOriginContent,
          originNameMatchOnly: originNameMatchOnly,
          trailingBriefMatch: trailingBriefMatch,
          includeTagMatches: includeTagMatches,
        ),
    ],
    'total': total ?? (paginated ? 21 : itemCount),
    'pn': pageNumber,
    'rn': 20,
  };
}

const _longOriginBrief =
    'This is a deliberately long Worldo brief used to verify that the '
    'search result card measures its complete content, wraps onto '
    'additional lines, and still keeps Latest Version visible.';

const _trailingMatchBrief =
    'Two delinquents who bully you are kissing?! You saw the whole scene '
    'on the rooftop';

Map<String, dynamic> _item(
  String type,
  int index, {
  bool longOriginContent = false,
  bool originNameMatchOnly = false,
  bool trailingBriefMatch = false,
  bool includeTagMatches = false,
}) {
  return switch (type) {
    'origin' => {
      'origin_id': 'origin_$index',
      'origin_name': 'Origin $index',
      'origin_version': '$index',
      'brief': trailingBriefMatch
          ? _trailingMatchBrief
          : longOriginContent
          ? _longOriginBrief
          : 'Origin brief $index',
      'language': 'en',
      'owner': {
        'uid': 'owner_$index',
        'name': index == 1 ? 'Deleted User' : 'Owner $index',
        'avatar': '',
      },
      'latestVersion': {'versionNum': index},
      'cover': '',
      'tags': ['tag-$index'],
      'characters': [
        {'character_id': 'character_$index', 'name': 'Character $index'},
        {'character_id': 'supporting_$index', 'name': 'Supporting $index'},
        if (longOriginContent)
          for (
            var characterIndex = 3;
            characterIndex <= 12;
            characterIndex += 1
          )
            {
              'character_id': 'extra_${index}_$characterIndex',
              'name': 'Extra Character $characterIndex',
            },
      ],
      'stats': {
        'copy_cnt': index,
        'discuss_cnt': index + 10,
        'connect_cnt': index,
        'character_cnt': index,
        'location_cnt': index + 20,
        'max_tick_cnt': index + 30,
      },
      'matches': [
        {
          'field': 'origin_name',
          'highlight_ranges': [
            {'start': 0, 'length': 6},
          ],
        },
        if (!originNameMatchOnly) ...[
          {
            'field': 'brief',
            'highlight_ranges': [
              if (trailingBriefMatch) ...[
                {
                  'start': _trailingMatchBrief.indexOf('rooftop'),
                  'length': 'rooftop'.length,
                },
              ] else ...[
                {'start': 0, 'length': 6},
                {'start': 7, 'length': 5},
              ],
              if (longOriginContent)
                {
                  'start': _longOriginBrief.indexOf('Latest Version visible'),
                  'length': 'Latest Version visible'.length,
                },
            ],
          },
          if (!longOriginContent)
            {
              'field': 'character_name',
              'character_id': 'character_$index',
              'highlight_ranges': [
                {'start': 0, 'length': 9},
              ],
            },
          if (!longOriginContent)
            {
              'field': 'character_name',
              'character_id': 'supporting_$index',
              'highlight_ranges': [
                {'start': 0, 'length': 10},
              ],
            },
          if (longOriginContent)
            {
              'field': 'character_name',
              'character_id': 'extra_${index}_12',
              'highlight_ranges': [
                {'start': 0, 'length': 'Extra Character 12'.length},
              ],
            },
          if (includeTagMatches)
            {
              'field': 'tag',
              'tag_index': 0,
              'highlight_ranges': [
                {'start': 0, 'length': 3},
              ],
            },
        ],
      ],
      'matches_truncated': false,
    },
    'world' => {
      'world_id': 'world_$index',
      'world_name': 'World $index',
      'origin_id': 'origin_$index',
      'language': 'en',
      'cover': '',
      'tags': ['world-tag-$index'],
      'owner': {'uid': 'owner_$index', 'name': 'Owner $index', 'avatar': ''},
      'stats': {
        'tick_cnt': index + 10,
        'connect_cnt': index + 20,
        'character_cnt': index + 30,
        'player_cnt': index + 40,
      },
      'created_at': 1777680000 + index,
      'matches': [
        {
          'field': 'world_name',
          'highlight_ranges': [
            {'start': 0, 'length': 5},
          ],
        },
        if (includeTagMatches)
          {
            'field': 'tag',
            'tag_index': 0,
            'highlight_ranges': [
              {'start': 6, 'length': 3},
            ],
          },
      ],
    },
    _ => {
      'uid': 'user_$index',
      'name': 'User $index',
      'avatar': '',
      'matches': [
        {
          'field': 'user_name',
          'highlight_ranges': [
            {'start': 0, 'length': 4},
          ],
        },
      ],
    },
  };
}

List<String> _highlightedTextParts(Text text) {
  final result = <String>[];

  void collect(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.style?.color == const Color(0xFFFF2442) && span.text != null) {
      expect(span.style?.backgroundColor, isNull);
      result.add(span.text!);
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      collect(child);
    }
  }

  final span = text.textSpan;
  if (span != null) collect(span);
  return result;
}

TransportResponse _jsonResponse(Map<String, dynamic> data) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
  );
}

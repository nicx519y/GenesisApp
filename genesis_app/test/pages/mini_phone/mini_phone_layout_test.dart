import '../../support/mini_phone_memory_cache.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_store.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_ui.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

import '../../support/mini_phone_chat_backend.dart';

Future<void> settleLayout(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  final boundary = GlobalKey();
  Future<void> mount(
    WidgetTester tester,
    MiniPhoneSession session,
    MiniPhoneScreen screen, {
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: MiniPhonePage(session: session, initialScreen: screen),
        ),
      ),
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['MINIPHONE_LAYOUT_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final box =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Messages errors use one transient toast and pulling does not refresh',
    (tester) async {
      final backend = PhoneBackend();
      var fail = false;
      const error = '服务暂时无法使用';
      backend.respond = (r) => fail && r.uri.path.endsWith('/dm_sessions')
          ? {'err_no': 5001, 'err_msg': error, 'data': {}}
          : null;
      final store = (await tester.runAsync(() async {
        final store = MiniPhoneStore(
          cacheStorage: MemoryMiniPhoneCacheStorage(),
          api: backend.api,
          worldId: 'w',
          namespace: 'messages-error-layout',
          readUid: () async => 'u',
          accountRevision: backend.revision,
          loadWorld: () async {
            if (fail) throw ApiException(message: error);
            return WorldDetail.fromJson({'name': 'World', 'characters': []});
          },
        );
        await store.ready;
        await store.refreshSessions();
        return store;
      }))!;
      final session = MiniPhoneSession(data: store);
      fail = true;
      await mount(tester, session, MiniPhoneScreen.messages);
      await settleLayout(tester);
      final row = find.byKey(const ValueKey('mini-phone-conversation-c'));
      expect(row, findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text(error), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text(error)),
        findsNothing,
      );
      final rowRect = tester.getRect(row);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(error), findsNothing);
      // Unrelated data changes must not replay a stale failure toast.
      await tester.runAsync(store.refreshSummary);
      await settleLayout(tester);
      expect(find.text(error), findsNothing);
      expect(tester.getRect(row), rowRect);

      final attempts = backend.calls('dm_sessions').length;
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await settleLayout(tester);
      expect(backend.calls('dm_sessions').length, attempts);
      expect(find.text(error), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(row, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  for (final screen in [
    MiniPhoneScreen.home,
    MiniPhoneScreen.posts,
    MiniPhoneScreen.photos,
  ]) {
    testWidgets(
      '${screen.name} read errors leave the original content geometry unchanged',
      (tester) async {
        final backend = PhoneBackend();
        var fail = false;
        const error = 'Service temporarily unavailable';
        backend.respond = (r) {
          if (fail &&
              [
                'home',
                'posts',
                'post/authors',
                'album',
              ].any((path) => r.uri.path.endsWith('/$path'))) {
            return {'err_no': 5001, 'err_msg': error, 'data': {}};
          }
          if (r.uri.path.endsWith('/home')) {
            return ok({
              'dms': {
                'unread_count': 1,
                'list': [phoneMessage(77)],
              },
              'posts': {'unread_count': 0, 'list': []},
            });
          }
          return null;
        };
        final store = (await tester.runAsync(() async {
          final s = backend.store();
          await s.ready;
          return s;
        }))!;
        final session = MiniPhoneSession(data: store);
        await mount(tester, session, screen);
        await settleLayout(tester);
        final anchor = switch (screen) {
          MiniPhoneScreen.home => find.text('Message 77'),
          MiniPhoneScreen.posts => find.text('Post body'),
          _ => find.text('Photos'),
        };
        final rect = tester.getRect(anchor);
        fail = true;
        await tester.runAsync(() async {
          switch (screen) {
            case MiniPhoneScreen.home:
              await store.refreshSummary();
            case MiniPhoneScreen.posts:
              await store.refreshPosts();
            default:
              await store.refreshAlbum();
          }
        });
        await settleLayout(tester);
        expect(find.text(error), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(tester.getRect(anchor), rect);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text(error),
          ),
          findsNothing,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(error), findsNothing);
        expect(tester.getRect(anchor), rect);
        await capture(tester, '${screen.name}-after-error');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }

  testWidgets(
    'the original Post action retries an uncertain write with the same request and content',
    (tester) async {
      final backend = PhoneBackend();
      var fail = true;
      backend.respond = (r) {
        if (fail && r.uri.path.endsWith('/post/create')) {
          throw ApiException(message: 'Connection lost');
        }
        return null;
      };
      final store = (await tester.runAsync(() async {
        final s = backend.store();
        await s.ready;
        return s;
      }))!;
      final session = MiniPhoneSession(data: store);
      await mount(tester, session, MiniPhoneScreen.create);
      await settleLayout(tester);
      final rect = tester.getRect(find.byType(GenesisPrimaryButton));
      await tester.enterText(find.byType(TextField), 'Original request');
      await tester.pump();
      await tester.runAsync(() => tester.tap(find.text('Post')));
      await settleLayout(tester);
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Retry same request'), findsNothing);
      expect(tester.getRect(find.byType(GenesisPrimaryButton)), rect);
      expect(
        tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(find.text('Original request'), findsOneWidget);
      fail = false;
      await tester.runAsync(() => tester.tap(find.text('Post')));
      await settleLayout(tester);
      final writes = backend.calls('post/create');
      expect(writes, hasLength(2));
      expect(backend.body(writes[1]), backend.body(writes[0]));
      expect(find.text('Posts'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.writesSaved);
      session.dispose();
    },
  );

  testWidgets(
    'Messages hides initial loading icons and preserves cached rows during refresh',
    (tester) async {
      final backend = PhoneBackend();
      var hold = false;
      var sessions = Completer<Object>();
      var people = Completer<WorldDetail>();
      backend.respond = (r) =>
          hold && r.uri.path.endsWith('/dm_sessions') ? sessions.future : null;
      final store = (await tester.runAsync(() async {
        final store = MiniPhoneStore(
          cacheStorage: MemoryMiniPhoneCacheStorage(),
          api: backend.api,
          worldId: 'w',
          namespace: 'layout',
          readUid: () async => 'u',
          accountRevision: backend.revision,
          loadWorld: () => hold
              ? people.future
              : Future.value(
                  WorldDetail.fromJson({'name': 'World', 'characters': []}),
                ),
        );
        await store.ready;
        store.sessions.clear();
        return store;
      }))!;
      hold = true;
      final session = MiniPhoneSession(data: store);
      await mount(tester, session, MiniPhoneScreen.messages);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(store.busy, containsAll(['sessions', 'people']));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Unread'), findsNothing);
      expect(find.text('New message'), findsNothing);
      expect(find.text('Nothing here yet.'), findsNothing);
      await capture(tester, 'messages-loading');
      await tester.runAsync(() async {
        sessions.complete(ok(page([phoneSession(unread: 2)])));
        people.complete(
          WorldDetail.fromJson({
            'name': 'World',
            'characters': [
              {'char_id': 'c', 'name': 'Character'},
            ],
          }),
        );
      });
      await settleLayout(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final row = find.byKey(const ValueKey('mini-phone-conversation-c'));
      expect(tester.getTopLeft(row).dy, 56);
      expect(find.byType(MiniBadge), findsOneWidget);
      await capture(tester, 'messages-live');
      sessions = Completer<Object>();
      people = Completer<WorldDetail>();
      final refreshing = Future.wait([
        store.refreshSessions(),
        store.refreshPeople(),
      ]);
      await tester.pump();
      expect(row, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.runAsync(() async {
        sessions.complete(ok(page([phoneSession(unread: 2)])));
        people.complete(
          WorldDetail.fromJson({
            'name': 'World',
            'characters': [
              {'char_id': 'c', 'name': 'Character'},
            ],
          }),
        );
        await refreshing;
      });
      await settleLayout(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets(
    'initial private chat hides loading icons while history is pending',
    (tester) async {
      final backend = PhoneBackend();
      final store = (await tester.runAsync(() async {
        final s = backend.store();
        await s.ready;
        return s;
      }))!;
      final history = Completer<Object>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/messages') ? history.future : null;
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: MiniPhoneLiveChat(
            store: store,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.runAsync(() async {
        history.complete(ok(page([])));
      });
      await settleLayout(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'private chat errors do not move the composer and Send safely retries',
    (tester) async {
      final backend = PhoneBackend();
      var fail = true;
      backend.respond = (r) {
        if (fail && r.uri.path.endsWith('/dm/send')) {
          throw ApiException(message: 'Message connection lost');
        }
        return null;
      };
      final store = (await tester.runAsync(() async {
        final s = backend.store();
        await s.ready;
        return s;
      }))!;
      store.phoneVisible = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: MiniPhoneLiveChat(
            store: store,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await settleLayout(tester);
      await tester.enterText(find.byType(TextField), 'Original message');
      await tester.pump();
      final composer = tester.widget<ChatComposer>(find.byType(ChatComposer));
      final rect = tester.getRect(find.byType(ChatComposer));
      await tester.runAsync(composer.onSend);
      await settleLayout(tester);
      expect(find.text('Message connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      // The existing typing/waiting line remains above the composer; errors add no row.
      final failedRect = tester.getRect(find.byType(ChatComposer));
      expect(failedRect.bottom, rect.bottom);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Message connection lost'), findsNothing);
      expect(tester.getRect(find.byType(ChatComposer)), failedRect);
      await tester.enterText(find.byType(TextField), 'Edited message');
      await tester.pump();
      fail = false;
      final retry = tester.widget<ChatComposer>(find.byType(ChatComposer));
      expect(retry.sendEnabled, isTrue);
      await tester.runAsync(retry.onSend);
      await settleLayout(tester);
      final writes = backend.calls('dm/send');
      expect(writes, hasLength(2));
      expect(backend.body(writes[1]), backend.body(writes[0]));
      expect(find.byType(ChatMessageRow), findsOneWidget);
      expect(find.text('Original message'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.writesSaved);
      store.dispose();
    },
  );

  testWidgets(
    'Create retains the original header action and photo border while publishing real data',
    (tester) async {
      final preview = MiniPhoneSession();
      await mount(tester, preview, MiniPhoneScreen.create);
      await settleLayout(tester);
      final originalPostRect = tester.getRect(
        find.byType(GenesisPrimaryButton),
      );
      await capture(tester, 'create-original');
      await tester.pumpWidget(const SizedBox.shrink());
      preview.dispose();
      final backend = PhoneBackend();
      final store = (await tester.runAsync(() async {
        final s = backend.store();
        await s.ready;
        return s;
      }))!;
      final session = MiniPhoneSession(data: store);
      await mount(tester, session, MiniPhoneScreen.create);
      await settleLayout(tester);
      expect(
        tester.getRect(find.byType(GenesisPrimaryButton)),
        originalPostRect,
      );
      expect(find.text('Player'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_MiniUploadBorder',
        ),
        findsOneWidget,
      );
      await capture(tester, 'create-live');
      final post = Completer<Object>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/post/create') ? post.future : null;
      await tester.enterText(find.byType(TextField), 'A real post');
      await tester.pump();
      await tester.runAsync(() => tester.tap(find.text('Post')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(
        backend.body(backend.calls('post/create').single)['content'],
        'A real post',
      );
      final action = tester.widget<GenesisPrimaryButton>(
        find.byType(GenesisPrimaryButton),
      );
      expect(action.isLoading, isTrue);
      expect(action.showLoadingIndicator, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await capture(tester, 'create-sending');
      await tester.runAsync(() async {
        post.complete(ok({}));
      });
      await settleLayout(tester);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(find.text('Load more'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is MiniIcon && w.name == 'plus' && w.size == 11,
        ),
        findsOneWidget,
      );
      expect(tester.getBottomRight(find.text('Day 2/10:00')).dx, 374);
      await capture(tester, 'posts-live');
      var failComment = true;
      backend.respond = (r) {
        if (failComment && r.uri.path.endsWith('/comment/create')) {
          throw ApiException(message: 'Comment connection lost');
        }
        if (r.uri.path.endsWith('/post/detail')) {
          return ok({...phoneDetail(), 'comment_count': 1});
        }
        if (r.uri.path.endsWith('/comments')) {
          return ok(
            page([
              {
                'comment_id': 9007199254740993,
                'post_id': 8,
                'author_type': 2,
                'author_id': 'c',
                'author_name': 'Character',
                'author_avatar_url': '',
                'comment_type': 2,
                'text': 'Reply to this real comment',
                'current_time': 'Day 2/10:00',
              },
            ]),
          );
        }
        return null;
      };
      await tester.tap(find.text('Be the first to comment'));
      await settleLayout(tester);
      expect(find.text('Reply to a comment'), findsNothing);
      expect(find.text('Write a comment…'), findsOneWidget);
      await capture(tester, 'comments-live');
      await tester.tap(find.text('Reply to this real comment'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'A real reply');
      await tester.pump();
      final send = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Send'),
      );
      expect(send.onPressed, isNotNull);
      final sendRect = tester.getRect(find.byTooltip('Send'));
      await tester.runAsync(() => tester.tap(find.byTooltip('Send')));
      await settleLayout(tester);
      expect(find.text('Comment connection lost'), findsOneWidget);
      expect(find.text('Retry same request'), findsNothing);
      expect(tester.getRect(find.byTooltip('Send')), sendRect);
      await tester.pump(const Duration(seconds: 3));
      failComment = false;
      await tester.runAsync(() => tester.tap(find.byTooltip('Send')));
      await settleLayout(tester);
      final writes = backend.calls('comment/create');
      expect(writes, hasLength(2));
      expect(backend.body(writes[1]), backend.body(writes[0]));
      expect(
        backend.calls('comment/create'),
        isNotEmpty,
        reason:
            'busy=${store.busy}, errors=${store.errors}, pending=${store.pending.keys}, paths=${backend.requests.map((r) => r.uri.path).toList()}',
      );
      final commentRequest = backend.requests.lastWhere(
        (r) => r.method == 'POST' && r.uri.path.endsWith('/comment/create'),
      );
      expect(
        backend.body(commentRequest)['reply_to_comment_id'],
        9007199254740993,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.writesSaved);
      session.dispose();
    },
  );

  testWidgets(
    'original-layout feed reaches further server pages by scrolling',
    (tester) async {
      final backend = PhoneBackend();
      backend.respond = (r) {
        if (!r.uri.path.endsWith('/posts')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return ok(
          page(
            [
              for (var i = 0; i < 10; i++)
                {
                  ...phonePost(),
                  'post_id': pn * 100 + i,
                  'text': 'Page $pn post $i',
                },
            ],
            pn: pn,
            total: 20,
          ),
        );
      };
      final store = (await tester.runAsync(() async {
        final s = backend.store();
        await s.ready;
        return s;
      }))!;
      final session = MiniPhoneSession(data: store);
      await mount(tester, session, MiniPhoneScreen.posts);
      await settleLayout(tester);
      expect(find.text('Load more'), findsNothing);
      for (
        var i = 0;
        i < 10 &&
            backend
                .calls('posts')
                .every((r) => r.uri.queryParameters['pn'] == '1');
        i++
      ) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -600));
        await settleLayout(tester);
      }
      expect(
        backend.calls('posts').any((r) => r.uri.queryParameters['pn'] == '2'),
        isTrue,
      );
      expect(store.posts.length, 20);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
  testWidgets('preview references and narrow live create retain their layout', (
    tester,
  ) async {
    for (final screen in [
      MiniPhoneScreen.messages,
      MiniPhoneScreen.posts,
      MiniPhoneScreen.comments,
    ]) {
      final preview = MiniPhoneSession();
      await mount(tester, preview, screen);
      await settleLayout(tester);
      await capture(tester, '${screen.name}-original');
      await tester.pumpWidget(const SizedBox.shrink());
      preview.dispose();
    }
    final backend = PhoneBackend();
    final store = (await tester.runAsync(() async {
      final s = backend.store();
      await s.ready;
      return s;
    }))!;
    final session = MiniPhoneSession(data: store);
    await mount(tester, session, MiniPhoneScreen.create, scale: 2, width: 320);
    await settleLayout(tester);
    expect(find.text('Post'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Post')).dy, lessThan(80));
    expect(tester.takeException(), isNull);
    await capture(tester, 'create-narrow-large-text');
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}

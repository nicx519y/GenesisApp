import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_create_post_page.dart';
import '../../support/mini_phone_chat_backend.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/photos/mini_phone_photo_projection.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_draft_photo.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_authors.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_list_requests.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';

PhoneAlbumAsset photo(int id, String url) => PhoneAlbumAsset.fromJson({
  'asset_id': id,
  'world_id': 'w',
  'image_url': url,
});

void main() {
  test(
    'photo projection reuses data and invalidates same-length replacements and covers',
    () {
      final projection = MiniPhonePhotoProjection();
      final album = [
        photo(1, 'https://cdn.test/a'),
        photo(2, 'https://cdn.test/a'),
        photo(3, 'https://cdn.test/b'),
        photo(4, ''),
      ];
      final visible = projection.resolve(album, {});
      expect(visible.map((p) => p.id), [1, 3]);
      expect(identical(projection.resolve(album, {}), visible), isTrue);
      expect(
        projection.resolve(album, {'https://cdn.test/a'}).map((p) => p.id),
        [3],
      );
      final replacement = [photo(5, 'https://cdn.test/c'), ...album.skip(1)];
      expect(projection.resolve(replacement, {}).map((p) => p.id), [5, 2, 3]);
      expect(album.length, 4);
    },
  );

  test(
    'fill only non-scrollable viewports; pagination respects refresh, visibility and errors',
    () async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      requests.hasMore['album'] = true;
      var active = true;
      final paging = MiniPhoneListRequests(requests, isActive: () => active);
      var calls = 0;
      Future<void> next() async {
        calls++;
      }

      FixedScrollMetrics metrics(double max, double pixels) =>
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: max,
            pixels: pixels,
            viewportDimension: 600,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          );
      paging.fillViewport('album', metrics(500, 480), next);
      expect(
        calls,
        0,
        reason: 'Being near the bottom is not an empty viewport',
      );
      paging.fillViewport('album', metrics(0, 0), next);
      expect(calls, 1);
      final refresh = Completer<void>();
      final refreshing = paging.refresh('album', () => refresh.future);
      paging.fillViewport('album', metrics(0, 0), next);
      expect(calls, 1);
      refresh.complete();
      await refreshing;
      active = false;
      paging.loadNext('album', next);
      expect(calls, 1);
      active = true;
      requests.foreground = false;
      paging.loadNext('album', next);
      expect(calls, 1);
      requests.foreground = true;
      requests.errors['album'] = 'offline';
      paging.loadNext('album', next);
      expect(calls, 1);
      requests.errors.clear();
      requests.busy.add('album');
      paging.loadNext('album', next);
      expect(calls, 1);
      requests.busy.clear();
      paging.loadNext('album', next);
      expect(calls, 2);
    },
  );

  testWidgets(
    'author strip builds visible slots lazily and scrolls to later authors',
    (tester) async {
      String? selected;
      var creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: MiniPhonePostAuthors(
                authors: [
                  for (var i = 0; i < 100; i++)
                    PhonePerson('$i', 'Person $i', ''),
                ],
                me: const PhonePerson('me', 'Me', ''),
                selectedId: null,
                onCreate: () => creates++,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('mini-phone-post-author-99')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-post-author-create')),
      );
      expect(creates, 1);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
      await tester.drag(find.byType(ListView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      final visible = find.byKey(const ValueKey('mini-phone-post-author-8'));
      await tester.ensureVisible(visible);
      await tester.tap(visible);
      expect(selected, '8');
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('de'), const Locale('zh', 'TW')]) {
    testWidgets(
      'localized create fits narrow large-text keyboard layout $locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = PhoneBackend();
        final store = (await tester.runAsync(() async {
          final store = backend.store();
          await store.ready;
          return store;
        }))!;
        final session = MiniPhoneSession(data: store);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: MiniPhoneCreatePostPage(
                store: store,
                draft: session.postDraft!,
                active: true,
                header: const SizedBox(height: 56),
                onPublished: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final copy = lookupAppLocalizations(locale);
        expect(find.text(copy.miniPhonePublish), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);
        await tester.enterText(find.byType(TextField), 'A draft');
        await tester.pump();
        expect(session.postDraft!.text, 'A draft');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }

  testWidgets(
    'draft preview decodes cover-sized pixels without altering upload bytes',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.pink, BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(1600, 1200);
        picture.dispose();
        final data = await original.toByteData(format: ui.ImageByteFormat.png);
        original.dispose();
        final bytes = data!.buffer.asUint8List();
        final originalLength = bytes.length;
        final provider = miniPhoneDraftPhotoProvider(
          bytes,
          devicePixelRatio: 3,
        );
        final loaded = Completer<ImageInfo>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (info, _) => loaded.complete(info),
          onError: (Object error, StackTrace? stack) =>
              loaded.completeError(error, stack),
        );
        stream.addListener(listener);
        final info = await loaded.future;
        expect(info.image.width, 384);
        expect(info.image.height, 288);
        expect(bytes.length, originalLength);
        expect(
          info.image.width * info.image.height,
          lessThan(1600 * 1200 / 10),
        );
        stream.removeListener(listener);
        info.dispose();
        await provider.evict();
      });
    },
  );
}

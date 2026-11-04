import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_preview_jobs.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_preview_album.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_widgets.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera_l10n.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

const scope = MiniPhoneCameraScope(
  environment: 'dev',
  accountId: 'u',
  worldId: 'w',
);
const person = PhonePerson('p', 'Person', '');
final sample = MiniPhoneCameraTemplate.povSelfie.assetPath;

void main() {
  testWidgets(
    'camera remains editable and jobs survive camera disposal and reentry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final camera = MiniPhoneCameraController(
        requests: requests,
        scope: scope,
      );
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(camera.dispose);
      addTearDown(jobs.dispose);
      camera.setPeople([person]);
      Widget page() => MaterialApp(
        theme: GenesisTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => MiniPhoneCameraPage(
              header: const SizedBox(height: 56),
              people: const [person],
              strings: miniPhoneCameraStrings(context),
              controller: camera,
              previewJobs: jobs,
              onCaptureRequested: () async {
                jobs.submit(
                  MiniPhoneCameraRequest(
                    scope: scope,
                    participants: camera.selectedPeople,
                    prompt: camera.prompt,
                    photoRatio: camera.photoRatio,
                  ),
                  sampleAsset: sample,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      final picker = find.byKey(const ValueKey('camera-ratio-picker'));
      final frame = find.byKey(const ValueKey('mini-phone-camera-viewfinder'));
      expect(tester.getSize(frame).aspectRatio, closeTo(2 / 3, .001));
      final cast = find.byKey(const ValueKey('camera-participants-region'));
      final originalCast = tester.getRect(cast);
      final originalPrompt = tester.getRect(find.byType(TextField));
      for (final ratio in CameraPhotoRatio.values) {
        final size = tester.getSize(
          find.byKey(ValueKey('camera-ratio-frame-${ratio.label}')),
        );
        expect(size.height, ratio.aspectRatio >= 1 ? 24 : 36);
        expect(size.aspectRatio, closeTo(ratio.aspectRatio, .001));
      }
      await tester.drag(picker, const Offset(-65, 0));
      await tester.pumpAndSettle();
      expect(camera.photoRatio, CameraPhotoRatio.tall);
      expect(tester.getSize(frame).aspectRatio, closeTo(9 / 16, .001));
      expect(tester.getRect(cast), originalCast);
      await tester.tap(find.byKey(const ValueKey('camera-ratio-1:1')));
      await tester.pumpAndSettle();
      expect(tester.getSize(frame).aspectRatio, closeTo(1, .001));
      expect(tester.getRect(cast), originalCast);
      await tester.tap(find.byKey(const ValueKey('camera-ratio-2:3')));
      await tester.pumpAndSettle();
      expect(camera.photoRatio, CameraPhotoRatio.portrait);
      for (final ratio in [CameraPhotoRatio.landscape, CameraPhotoRatio.wide]) {
        camera.setPhotoRatio(ratio);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(frame).aspectRatio,
          closeTo(ratio.aspectRatio, .001),
        );
        expect(tester.getRect(cast), originalCast);
        expect(tester.getRect(find.byType(TextField)), originalPrompt);
        expect(
          tester
              .getCenter(find.byKey(ValueKey('camera-ratio-${ratio.label}')))
              .dx,
          closeTo(tester.getCenter(picker).dx, .1),
        );
        expect(tester.takeException(), isNull);
      }
      camera.setPhotoRatio(CameraPhotoRatio.portrait);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MiniPhoneCameraShutter));
      await tester.pump();
      expect(jobs.tasks, isEmpty);
      expect(
        find.text('Tap the people below to bring them into the frame.'),
        findsWidgets,
      );
      camera.togglePerson(person);
      await tester.pump();
      await tester.tap(find.byType(MiniPhoneCameraShutter));
      await tester.pump();
      final flight = find.byKey(const ValueKey('camera-capture-flight-1'));
      expect(flight, findsOneWidget);
      final initialFlightSize = tester.getSize(flight);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getSize(flight).width, lessThan(initialFlightSize.width));
      await tester.pump(const Duration(milliseconds: 650));
      expect(flight, findsNothing);
      camera.setPhotoRatio(CameraPhotoRatio.square);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Second picture');
      await tester.tap(find.byType(MiniPhoneCameraShutter));
      await tester.pump();
      expect(jobs.pendingCount, 2);
      expect(jobs.tasks.map((t) => t.request.aspectRatio), [1, 2 / 3]);
      expect(camera.phase, MiniPhoneCameraPhase.compose);
      expect(find.text('2 generating'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(jobs.unreadCount, 2);
      await tester.pumpWidget(page());
      expect(camera.prompt, 'Second picture');
      expect(find.byType(TextField), findsOneWidget);
      expect(jobs.tasks.map((t) => t.request.prompt), ['Second picture', '']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed photo is informational and successful photos open normally',
    (tester) async {
      tester.view.physicalSize = const Size(350, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(jobs.dispose);
      String? selectedPostAsset;
      for (var i = 0; i < 3; i++) {
        jobs.submit(
          MiniPhoneCameraRequest(
            scope: scope,
            participants: [person],
            prompt: 'Photo $i',
          ),
          sampleAsset: sample,
        );
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: jobs,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  CameraPreviewAlbumSliver(
                    jobs: jobs,
                    onUseInPost: (asset) => selectedPostAsset = asset,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final tile = find.byKey(const ValueKey('camera-preview-task-3'));
      final before = tester.getRect(tile);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Try again'), findsNothing);
      expect(
        find.text('Generation failed. Any Gems charged will be refunded.'),
        findsOneWidget,
      );
      expect(tester.getRect(tile), before);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: tile, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
      await tester.tap(tile);
      await tester.pump();
      expect(jobs.pendingCount, 0);
      await tester.pump(const Duration(seconds: 30));
      expect(jobs.tasks.first.state, CameraPreviewTaskState.failed);
      expect(jobs.tasks.first.attempt, 1);
      expect(jobs.tasks.length, 3);
      expect(tester.getRect(tile), before);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('camera-preview-task-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('camera-photo-use-in-post')));
      await tester.pumpAndSettle();
      expect(selectedPostAsset, sample);
      expect(
        find.byKey(const ValueKey('camera-photo-use-in-post')),
        findsNothing,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(tile, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

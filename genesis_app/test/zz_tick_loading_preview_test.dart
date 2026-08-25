// TEMPORARY preview harness - renders the two tick loading surfaces (the
// Tick-now wait dialog and the in-chat tick progress bubble) to a PNG so
// their styling can be reviewed against the redesign system. Delete after
// the design review.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/genesis_generation_wait_overlay.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      final loader = FontLoader(family);
      for (final font
          in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  testWidgets('preview: tick-now wait dialog', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390 * 3, 700 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GenesisTheme.worldoDark(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.genesisColors.pageBackground,
            body: RepaintBoundary(
              key: const ValueKey<String>('preview'),
              child: ColoredBox(
                color: context.genesisColors.pageBackground,
                child: const GenesisGenerationWaitOverlay(
                  title: 'Progressing the world',
                  message:
                      'The narrator is moving every character forward.\n'
                      'Please wait for a moment.',
                  characterAvatars: [
                    GenesisGenerationWaitAvatar(name: 'Vivienne', url: ''),
                    GenesisGenerationWaitAvatar(name: 'Adrian', url: ''),
                    GenesisGenerationWaitAvatar(name: 'Dorian', url: ''),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byKey(const ValueKey<String>('preview')),
      matchesGoldenFile('preview/tick_now_dialog.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preview: in-chat tick progress bubble', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390 * 3, 360 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GenesisTheme.worldoDark(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: const Color(0xFF111111),
            body: RepaintBoundary(
              key: const ValueKey<String>('preview'),
              child: ColoredBox(
                color: const Color(0xFF111111),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChatMessageRow(
                        message: ChatMessageVm(
                          localId: 'tick-progress',
                          senderId: 'tick',
                          senderName: 'Time',
                          text: '',
                          isMe: false,
                          status: 'progressing',
                          senderType: 'tick',
                          timelinePayload: const ChatTickProgressPayloadVm(
                            title: 'Progressing the World',
                            avatars: [
                              ChatTickProgressAvatarVm(name: 'Vivienne', url: ''),
                              ChatTickProgressAvatarVm(name: 'Adrian', url: ''),
                              ChatTickProgressAvatarVm(name: 'Dorian', url: ''),
                            ],
                          ),
                        ),
                        showDateDivider: false,
                        style: context.genesisChatTheme.locationChat,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byKey(const ValueKey<String>('preview')),
      matchesGoldenFile('preview/tick_progress_bubble.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

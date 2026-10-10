import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_type.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';

/// Measures where the composer's hint, its first line of text and the speaker
/// mark sit, across system text scales, so their alignment is judged from
/// numbers rather than by eye. The phone this was tuned on runs at 0.9.
void main() {
  for (final scale in [0.9, 1.0, 1.3]) {
    for (final narrating in [false, true]) {
      testWidgets('composer alignment scale=$scale narrating=$narrating', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 200);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.runAsync(() async {
          final font = FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
          await font.load();
        });
        final controller = LocationChatMentionEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFF151517),
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: LocationChatComposerInput(
                    controller: controller,
                    focusNode: focus,
                    inputEnabled: true,
                    sendEnabled: false,
                    sending: false,
                    onSend: () async {},
                    selfName: 'Luna',
                    messageType: narrating
                        ? chatroomNarrationMessageType
                        : chatroomTextMessageType,
                    onToggleMessageType: () {},
                    style: kLocationChatStyle,
                    bottomSafeAreaInset: 0,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final hint = find.text(
          narrating ? 'Message as the Narrator' : 'Message as Luna',
        );
        final mark = find.byKey(
          ValueKey(narrating ? 'speaker-narrator' : 'speaker-character'),
        );
        final surface = find.byKey(
          const ValueKey<String>('chat-composer-input-surface'),
        );
        final surfaceRect = tester.getRect(surface);
        final markCentre = tester.getRect(mark).center.dy;
        final hintCentre = tester.getRect(hint).center.dy;
        debugPrint(
          'PROBE scale=$scale narrating=$narrating  box '
          '${surfaceRect.height.toStringAsFixed(1)}  hint '
          '${(hintCentre - surfaceRect.top).toStringAsFixed(2)}  mark '
          '${(markCentre - surfaceRect.top).toStringAsFixed(2)}  '
          'box mid ${(surfaceRect.height / 2).toStringAsFixed(2)}',
        );

        // Long text: the mark must stay on the first line as the box grows.
        controller.text = [
          'First line',
          'second line',
          'third line',
        ].join(String.fromCharCode(10));
        await tester.pumpAndSettle();
        final grown = tester.getRect(surface);
        final editable = tester.getRect(find.byType(EditableText));
        final lineHeight = editable.height / 3;
        final firstLine = editable.top + lineHeight / 2 - grown.top;
        debugPrint(
          'PROBE scale=$scale narrating=$narrating  multi  first line '
          '${firstLine.toStringAsFixed(2)}  mark '
          '${(tester.getRect(mark).center.dy - grown.top).toStringAsFixed(2)}',
        );
        controller.clear();
        await tester.pumpAndSettle();

        if (scale == 1.0) {
          await tester.runAsync(() async {
            final box =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await box.toImage(pixelRatio: 3);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              'test/preview/composer_align_${narrating ? 'narrator' : 'character'}.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}

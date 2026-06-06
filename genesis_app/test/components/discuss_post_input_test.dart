import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_upload_progress_overlay.dart';
import 'package:genesis_flutter_android/components/discuss/discuss_post_input.dart';

void main() {
  testWidgets('dismisses composer when tapping outside the sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => const <DiscussPickedImage>[],
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );
    final composerInput = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Write a post').last,
    );
    expect(composerInput.minLines, 3);
    expect(composerInput.maxLines, 6);
    expect(composerInput.expands, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.byKey(const ValueKey('discuss-composer-sheet')), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discuss-composer-sheet')), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('New post'), findsNothing);
  });

  testWidgets('composer grows from three to six lines then scrolls', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => const <DiscussPickedImage>[],
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('discuss-composer-sheet'));
    final input = find.widgetWithText(TextField, 'Write a post').last;
    final initialHeight = tester.getSize(sheet).height;

    await tester.enterText(input, 'one\ntwo\nthree\nfour\nfive\nsix');
    await tester.pump();
    final sixLineHeight = tester.getSize(sheet).height;

    expect(sixLineHeight, greaterThan(initialHeight));

    await tester.enterText(
      input,
      'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight',
    );
    await tester.pump();

    expect(tester.getSize(sheet).height, sixLineHeight);
  });

  testWidgets('dismisses composer directly when route back is pressed', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => const <DiscussPickedImage>[],
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byKey(const ValueKey('discuss-composer-sheet')), findsNothing);

    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('New post'), findsNothing);
  });

  testWidgets('dismisses composer when keyboard back is consumed by IME', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => const <DiscussPickedImage>[],
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.binding.handleMetricsChanged();
    await tester.pump();

    tester.view.viewInsets = FakeViewPadding.zero;
    tester.binding.handleMetricsChanged();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('discuss-composer-sheet')), findsNothing);

    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('New post'), findsNothing);
  });

  testWidgets('picks up to six images and waits for uploads before posting', (
    WidgetTester tester,
  ) async {
    final uploadCompleters = <Completer<String>>[];
    var submittedContent = '';
    var submittedImages = const <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => List<DiscussPickedImage>.generate(
              8,
              (index) => _pickedImage(index),
            ),
            imageUploader: (image) {
              final completer = Completer<String>();
              uploadCompleters.add(completer);
              return completer.future;
            },
            submitter: (content, images) async {
              submittedContent = content;
              submittedImages = images;
              return <String, dynamic>{'discuss_id': 'dis_new'};
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();
    final sheetSizeBeforeImages = tester.getSize(
      find.byKey(const ValueKey('discuss-composer-sheet')),
    );
    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pump();
    await tester.pump();

    expect(uploadCompleters, hasLength(6));
    for (var i = 0; i < discussPostMaxImages; i++) {
      expect(find.byKey(ValueKey('discuss-image-thumb-$i')), findsOneWidget);
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('discuss-composer-sheet'))),
      sheetSizeBeforeImages,
    );
    final stripRect = tester.getRect(
      find.byKey(const ValueKey('discuss-image-strip')),
    );
    final firstThumbRect = tester.getRect(
      find.byKey(const ValueKey('discuss-image-thumb-0')),
    );
    final lastThumbRect = tester.getRect(
      find.byKey(const ValueKey('discuss-image-thumb-5')),
    );
    expect(firstThumbRect.left, closeTo(stripRect.left, 0.01));
    expect(lastThumbRect.right, closeTo(stripRect.right, 0.01));
    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsNothing,
    );
    expect(find.byType(GenesisUploadProgressOverlay), findsNWidgets(6));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a post').last,
      'Post with images',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(submittedContent, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    for (var i = 0; i < uploadCompleters.length; i++) {
      uploadCompleters[i].complete('https://cdn.example.com/$i.jpg');
    }
    await tester.pumpAndSettle();

    expect(submittedContent, 'Post with images');
    expect(submittedImages, [
      for (var i = 0; i < discussPostMaxImages; i++)
        'https://cdn.example.com/$i.jpg',
    ]);
    expect(find.text('New post'), findsNothing);
  });

  testWidgets('shows add tile below limit and removes selected images', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => <DiscussPickedImage>[_pickedImage(0)],
            imageUploader: (image) async => 'https://cdn.example.com/0.jpg',
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discuss-image-thumb-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('discuss-image-remove-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discuss-image-thumb-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsNothing,
    );
  });

  testWidgets('can add images again after removing a selected image', (
    WidgetTester tester,
  ) async {
    var pickCount = 0;
    final requestedLimits = <int>[];
    final uploadedFilenames = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async {
              pickCount += 1;
              requestedLimits.add(limit);
              if (pickCount == 1) {
                return List<DiscussPickedImage>.generate(
                  6,
                  (index) => _pickedImage(index),
                );
              }
              return <DiscussPickedImage>[_pickedImage(99)];
            },
            imageUploader: (image) async {
              uploadedFilenames.add(image.filename);
              return 'https://cdn.example.com/${image.filename}';
            },
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pumpAndSettle();

    expect(pickCount, 1);
    expect(requestedLimits, <int>[6]);
    expect(uploadedFilenames, hasLength(6));
    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('discuss-image-remove-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('discuss-image-add-button')));
    await tester.pumpAndSettle();

    expect(pickCount, 2);
    expect(requestedLimits, <int>[6, 1]);
    expect(uploadedFilenames, contains('image_99.png'));
    expect(find.byKey(const ValueKey('discuss-image-thumb-6')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discuss-image-add-button')),
      findsNothing,
    );
  });

  testWidgets('keeps composer visible while image picker is open', (
    WidgetTester tester,
  ) async {
    final pickerCompleter = Completer<List<DiscussPickedImage>>();
    var pickerStarted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) {
              pickerStarted = true;
              return pickerCompleter.future;
            },
            imageUploader: (image) async => 'https://cdn.example.com/0.jpg',
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pump();
    await tester.pump();

    expect(pickerStarted, isTrue);
    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );

    pickerCompleter.complete(const <DiscussPickedImage>[]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('keeps composer above keyboard after images are added', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async => <DiscussPickedImage>[_pickedImage(0)],
            imageUploader: (image) async => 'https://cdn.example.com/0.jpg',
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    final keyboardTop = tester.view.physicalSize.height - 320;
    final sheetRectBeforeImages = tester.getRect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
    );
    expect(sheetRectBeforeImages.bottom, lessThanOrEqualTo(keyboardTop));

    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pumpAndSettle();

    final sheetRectAfterImages = tester.getRect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
    );
    expect(sheetRectAfterImages.bottom, lessThanOrEqualTo(keyboardTop));
    expect(sheetRectAfterImages.height, sheetRectBeforeImages.height);
  });

  testWidgets('resyncs composer position when keyboard settles after picker', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussPostInput(
            bizId: 'o_test_1',
            imagePicker: (limit) async {
              tester.view.viewInsets = const FakeViewPadding(bottom: 80);
              return const <DiscussPickedImage>[];
            },
            imageUploader: (image) async => 'https://cdn.example.com/0.jpg',
            submitter: (content, images) async => <String, dynamic>{},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();
    final sheetSizeBeforePicker = tester.getSize(
      find.byKey(const ValueKey('discuss-composer-sheet')),
    );

    await tester.tap(find.byKey(const ValueKey('discuss-image-picker-button')));
    await tester.pump(const Duration(milliseconds: 20));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump(const Duration(milliseconds: 360));

    final keyboardTop = tester.view.physicalSize.height - 320;
    final sheetRectAfterKeyboardSettles = tester.getRect(
      find.byKey(const ValueKey('discuss-composer-sheet')),
    );
    expect(
      sheetRectAfterKeyboardSettles.bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(sheetRectAfterKeyboardSettles.size, sheetSizeBeforePicker);
  });

  testWidgets(
    'keeps selected images in composer when picker returns before keyboard',
    (WidgetTester tester) async {
      final uploadCompleter = Completer<String>();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 900);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussPostInput(
              bizId: 'o_test_1',
              imagePicker: (limit) async {
                tester.view.viewInsets = const FakeViewPadding(bottom: 80);
                tester.binding.handleMetricsChanged();
                return <DiscussPickedImage>[_pickedImage(0)];
              },
              imageUploader: (image) => uploadCompleter.future,
              submitter: (content, images) async => <String, dynamic>{},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextField, 'Write a post'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('discuss-image-picker-button')),
      );
      await tester.pump();

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.binding.handleMetricsChanged();
      await tester.pump(const Duration(milliseconds: 360));

      expect(
        find.byKey(const ValueKey('discuss-composer-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discuss-image-thumb-0')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('discuss-composer-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discuss-image-thumb-0')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1500));
      uploadCompleter.complete('https://cdn.example.com/0.jpg');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('discuss-composer-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discuss-image-thumb-0')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('discuss-composer-sheet')),
        findsNothing,
      );
    },
  );
}

DiscussPickedImage _pickedImage(int index) {
  return DiscussPickedImage(
    bytes: Uint8List.fromList(_transparentPng),
    filename: 'image_$index.png',
    contentType: 'image/png',
  );
}

const _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

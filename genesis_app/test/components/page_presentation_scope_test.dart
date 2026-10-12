import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/page_presentation_scope.dart';

void main() {
  test('nested covers resume only after the last owner releases', () {
    final controller = PagePresentationController();
    final changes = <bool>[];
    controller.addListener(() => changes.add(controller.paused));
    final first = controller.cover();
    final second = controller.cover();
    first();
    first();
    expect(controller.paused, isTrue);
    second();
    expect(controller.paused, isFalse);
    expect(changes, [true, false]);
    final releaseAfterDisposal = controller.cover();
    controller.dispose();
    releaseAfterDisposal();
  });

  testWidgets('cover blocks duplicate entry and resumes after failure', (
    tester,
  ) async {
    final controller = PagePresentationController();
    addTearDown(controller.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      PagePresentationScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final pending = Completer<void>();
    final opened = PagePresentationScope.runCovered(
      pageContext,
      () => pending.future,
    );
    expect(controller.paused, isTrue);
    var duplicateOpened = false;
    await PagePresentationScope.runCovered(pageContext, () async {
      duplicateOpened = true;
    });
    expect(duplicateOpened, isFalse);
    pending.complete();
    await opened;
    expect(controller.paused, isFalse);
    await expectLater(
      PagePresentationScope.runCovered(pageContext, () async {
        throw StateError('failed to open');
      }),
      throwsStateError,
    );
    expect(controller.paused, isFalse);
  });
}

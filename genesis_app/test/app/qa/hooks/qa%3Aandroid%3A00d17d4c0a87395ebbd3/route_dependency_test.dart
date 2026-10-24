import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart'
    as hook;
import 'subject.dart';

void main() {
  testWidgets(
    'route scans do not create inherited self dependencies across navigation',
    (tester) async {
      final fixture = await mountSubject(tester);
      try {
        for (var pass = 0; pass < 2; pass++) {
          final inherited = <Element>[];
          final routes = <ModalRoute<dynamic>>{};
          void scan(Element element) {
            if (element is InheritedElement) inherited.add(element);
            final route = hook.observedRoute(element);
            if (route != null) routes.add(route);
            element.visitChildren(scan);
          }

          scan(tester.binding.rootElement!);
          expect(inherited, isNotEmpty);
          for (final element in inherited) {
            expect(hook.observedRoute(element), isNull);
          }
          expect(routes, contains(fixture.route));
          expect(await hook.invoke({'operation': 'read'}, false, true), true);
          // A transparent route leaves the panel mounted and painted: the route
          // check itself must reject it, not just Offstage filtering.
          final cover = PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, __, ___) => const SizedBox.expand(),
          );
          fixture.navigator.push(cover);
          try {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              await hook.invoke({'operation': 'read'}, false, true),
              false,
            );
          } finally {
            fixture.navigator.removeRoute(cover);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(await hook.invoke({'operation': 'read'}, false, true), true);
        }
      } finally {
        await closeSubject(tester, fixture);
      }
      expect(fixture.released, true);
      expect(fixture.service.state.connected, false);
      expect(tester.takeException(), isNull);
    },
  );
}

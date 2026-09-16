import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contact sheet of the icons that could lead a benefit row, so one can be
/// chosen by looking rather than by filename.
void main() {
  testWidgets('render benefit icon candidates', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/dev/flutter/bin/cache/artifacts/material_fonts/'
            'materialicons-regular.otf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    });

    const svgs = <String>[
      'gem_diamond',
      'icon_gems_stack',
      'icon_benefit_inspiration',
      'icon_benefit_edit',
      'edit_pencil_line',
      'icon_benefit_badge',
      'paragraph_icon',
      'clue',
      'upgrade',
      'refresh_2',
      'arrow-change-svgrepo-com',
      'records',
      'info',
      'worlddetail-icon',
      'character_icon',
      'go_on',
      'route',
      'connect_icon',
      'events',
      'world_tab_status',
      'launch_icon',
    ];
    const material = <String, IconData>{
      'auto_stories': Icons.auto_stories_outlined,
      'psychology': Icons.psychology_outlined,
      'history_edu': Icons.history_edu_outlined,
      'bookmarks': Icons.bookmarks_outlined,
      'add_card': Icons.add_card_outlined,
      'sd_storage': Icons.sd_storage_outlined,
      'all_inclusive': Icons.all_inclusive,
      'workspace_premium': Icons.workspace_premium_outlined,
      'bolt': Icons.bolt_outlined,
      'stars': Icons.stars_outlined,
    };

    Widget cell(String label, Widget art) => SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 26, child: Center(child: art)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Colors.white70),
          ),
        ],
      ),
    );

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: const Color(0xFF181C1F),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 4,
                runSpacing: 14,
                children: [
                  for (final name in svgs)
                    cell(
                      name,
                      SvgPicture.asset(
                        'assets/custom-icons/svg/$name.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFF5C24B),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  for (final entry in material.entries)
                    cell(
                      'M: ${entry.key}',
                      Icon(
                        entry.value,
                        size: 22,
                        color: const Color(0xFFF5C24B),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        'test/preview/benefit_icon_candidates.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}

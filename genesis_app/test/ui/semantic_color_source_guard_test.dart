import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrated surfaces do not reintroduce unmanaged static colors', () {
    const roots = <String>[
      'lib/pages/me',
      'lib/components/me',
      'lib/pages/home',
      'lib/components/home',
      'lib/pages/messages',
      'lib/pages/discuss',
      'lib/components/discuss',
      'lib/pages/search',
      'lib/pages/origin_editor',
      'lib/pages/create',
      'lib/pages/edit',
    ];
    const files = <String>[
      'lib/pages/world/world_constants.dart',
      'lib/pages/world/world_header.dart',
      'lib/pages/world/world_sections.dart',
      'lib/pages/world/world_bottom_sheet.dart',
      'lib/pages/world/world_page.dart',
      'lib/components/world_details_shell.dart',
      'lib/components/world_top_overlay_bar.dart',
      'lib/components/world_tick_event_item.dart',
      'lib/components/world_location_list.dart',
      'lib/components/common/copyable_id_label.dart',
      'lib/components/common/genesis_report_actions.dart',
      'lib/pages/origin/origin_world_page.dart',
      'lib/pages/origin/origin_world_sections.dart',
      'lib/pages/origin/origin_world_detail_sheet.dart',
      'lib/pages/origin/origin_world_map_shell.dart',
      'lib/pages/origin/origin_world_copy_progress.dart',
      'lib/pages/origin/origin_launch_coordinator.dart',
      'lib/components/origin/characters_list.dart',
      'lib/components/origin/stat_item.dart',
      'lib/components/origin/origin_role_launch_sheet.dart',
      'lib/components/origin/origin_item_card.dart',
      'lib/components/search_bar.dart',
      'lib/ui/components/genesis_search_field.dart',
      'lib/pages/gems/gem_wallet_page.dart',
      'lib/components/gems/gem_colors.dart',
      'lib/components/gems/gem_purchase_catalog.dart',
      'lib/components/gems/gem_purchase_bottom_sheet.dart',
      'lib/components/gems/gem_billing_purchase_dialog.dart',
      'lib/components/gems/daily_check_in_dialog.dart',
      'lib/components/common/genesis_generation_wait_overlay.dart',
    ];
    final colorLiteral = RegExp(r'\bColor\(0x[0-9A-Fa-f]{8}\)');
    final namedColor = RegExp(
      r'\bColors\.(?!transparent\b)[A-Za-z][A-Za-z0-9_]*',
    );
    final offenders = <String>[];

    for (final root in roots) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        if (file.path.endsWith('developer_color_configuration_page.dart')) {
          // The editor intentionally uses a fixed safety palette so a broken
          // developer override cannot make reset/navigation controls unusable.
          continue;
        }
        final source = file.readAsStringSync();
        if (colorLiteral.hasMatch(source) || namedColor.hasMatch(source)) {
          offenders.add(file.path);
        }
      }
    }
    for (final path in files) {
      final source = File(path).readAsStringSync();
      if (colorLiteral.hasMatch(source) || namedColor.hasMatch(source)) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty);
  });
}

import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';
import '../../../../pages/world/world_bottom_sheet.dart';
import '../../../../components/world_location_list.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validateRead(p, started);
  final lease = requireWorldLease();
  await lease.sameOwner();
  final sheets = elements().where(
    (e) =>
        e.widget is WorldSingleSectionBottomSheet &&
        (e.widget as WorldSingleSectionBottomSheet).initialWorld.worldId ==
            lease.worldId &&
        visible(e),
  );
  final lists = sheets
      .expand((e) => elements(e))
      .where((e) => e.widget is WorldLocationList && visible(e))
      .toList();
  final shown = lists.any(
    (e) => textElements(lease.locationName, e).isNotEmpty,
  );
  return {
    'locationsViewVisible': lists.isNotEmpty,
    'worldIdMatchesPreparedWorld': sheets.isNotEmpty,
    'targetWorldLocationsDisplayed': shown,
  };
}

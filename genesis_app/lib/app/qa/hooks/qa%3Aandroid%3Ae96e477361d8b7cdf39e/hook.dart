import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253A5b3990fd6789b5efbe42/hook.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  final before = baseline().events;
  return displayedEvents()
      .where(
        (e) => !before.any(
          (old) => const DeepCollectionEqualityForWorld().equal(old, e),
        ),
      )
      .length;
}

import 'package:flutter/foundation.dart';

import '../../components/world_memory/world_memory_models.dart';
import '../../components/world_memory/world_memory_preview_data.dart';
import '../../l10n/genesis_l10n.dart';

/// Debug-only stand-in for structured memory and Deluxe until their backend
/// exists, so the designs can be seen through the real World, MiniPhone, Me and
/// wallet entries.
///
/// Held in memory only: a restart returns to the default set in `main`, and
/// release builds never honour it.
enum WorldMemoryDebugMembership {
  off,
  free,
  premium,
  deluxe,
  both;

  String get label => switch (this) {
    off => GenesisL10n.current.developerRecapOff,
    free => GenesisL10n.current.memoryPreviewFree,
    premium => 'Premium',
    deluxe => 'Deluxe',
    both => GenesisL10n.current.memoryPreviewBoth,
  };
}

enum WorldMemoryDebugStory {
  live,
  fresh,
  departures;

  String get label => switch (this) {
    live => GenesisL10n.current.memoryPreviewLive,
    fresh => GenesisL10n.current.memoryPreviewFresh,
    departures => GenesisL10n.current.memoryPreviewDepartures,
  };
}

class WorldMemoryDebugPreview {
  const WorldMemoryDebugPreview({
    this.membership = WorldMemoryDebugMembership.off,
    this.story = WorldMemoryDebugStory.live,
  });

  final WorldMemoryDebugMembership membership;
  final WorldMemoryDebugStory story;

  bool get premium =>
      membership == WorldMemoryDebugMembership.premium ||
      membership == WorldMemoryDebugMembership.both;

  bool get deluxe =>
      membership == WorldMemoryDebugMembership.deluxe ||
      membership == WorldMemoryDebugMembership.both;

  DateTime? get premiumExpiry => premium ? DateTime(2027, 9, 7) : null;

  DateTime? get deluxeExpiry => deluxe ? DateTime(2027, 11, 3) : null;

  WorldMemorySnapshot get snapshot => switch (story) {
    WorldMemoryDebugStory.live => WorldMemoryPreviewData.live(),
    WorldMemoryDebugStory.fresh => WorldMemoryPreviewData.fresh(),
    WorldMemoryDebugStory.departures => WorldMemoryPreviewData.departures(),
  };

  /// Sample count behind the World capsule dot and the MiniPhone home badge.
  int updatesFor(WorldMemorySection section) {
    if (story == WorldMemoryDebugStory.fresh) return 0;
    if (deluxe) return section == WorldMemorySection.cast ? 2 : 1;
    return premium && section == WorldMemorySection.recap ? 1 : 0;
  }

  WorldMemoryDebugPreview copyWith({
    WorldMemoryDebugMembership? membership,
    WorldMemoryDebugStory? story,
  }) => WorldMemoryDebugPreview(
    membership: membership ?? this.membership,
    story: story ?? this.story,
  );
}

final ValueNotifier<WorldMemoryDebugPreview> worldMemoryDebugPreview =
    ValueNotifier(const WorldMemoryDebugPreview());

/// The preview in force, or null to use the real account and its real data.
WorldMemoryDebugPreview? get activeWorldMemoryDebugPreview {
  if (!kDebugMode) return null;
  final preview = worldMemoryDebugPreview.value;
  return preview.membership == WorldMemoryDebugMembership.off ? null : preview;
}

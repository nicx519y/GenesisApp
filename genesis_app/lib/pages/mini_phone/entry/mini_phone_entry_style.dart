import 'package:flutter/widgets.dart';

import 'mini_phone_entry_motion.dart';

/// Only assets, geometry and keyframes vary. State and rendering are shared.
enum MiniPhoneEntryStyle {
  classicHandset,
  arcaneGrimoire;

  /// Use the final World era, never infer from Origin, tags or map imagery.
  static MiniPhoneEntryStyle fromMapEra(String? era) =>
      switch (era?.trim().toLowerCase()) {
        'mythic_ancient' ||
        'historical_east' ||
        'medieval_fantasy' ||
        'victorian' ||
        'steampunk' => arcaneGrimoire,
        'modern' ||
        'near_future' ||
        'cyberpunk' ||
        'space_scifi' ||
        'post_apocalyptic' => classicHandset,
        _ => classicHandset,
      };

  MiniPhoneEntrySkin get skin => switch (this) {
    classicHandset => _handset,
    arcaneGrimoire => _grimoire,
  };
}

class MiniPhoneEntrySkin {
  const MiniPhoneEntrySkin({
    required this.bodyAsset,
    required this.unreadAsset,
    required this.unreadRect,
    required this.musicOffset,
    required this.arrivalMotion,
    this.decorationAsset,
    this.decorationRect,
    this.clockRect,
    this.unreadMotion,
    this.unreadGlow = false,
  });
  final String bodyAsset, unreadAsset;
  final String? decorationAsset;
  final Rect unreadRect;
  final Rect? decorationRect, clockRect;
  final Offset musicOffset;
  final EntryMotion arrivalMotion;
  final EntryMotion? unreadMotion;
  final bool unreadGlow;
}

// Geometry: design-tokens.json and components/*.svg.
// Keyframes: web-animated/*/01-arrival.svg and source-reference/phone-icons.css.
const _handset = MiniPhoneEntrySkin(
  bodyAsset: 'entry-classic-handset-body',
  unreadAsset: 'entry-classic-handset-unread',
  unreadRect: Rect.fromLTWH(5, 27.5, 24, 12),
  clockRect: Rect.fromLTWH(2, 14, 30, 9),
  musicOffset: Offset(9, 27.9),
  arrivalMotion: EntryMotion(760, [
    EntryKeyframe(0),
    EntryKeyframe(.12, x: -1.2, rotation: -8),
    EntryKeyframe(.24, x: 1.2, rotation: 8),
    EntryKeyframe(.36, x: -1.2, rotation: -8),
    EntryKeyframe(.48, x: 1.2, rotation: 8),
    EntryKeyframe(.60, x: -1.2, rotation: -8),
    EntryKeyframe(.72, x: 1.2, rotation: 8),
    EntryKeyframe(.86, x: -.5, rotation: -3),
    EntryKeyframe(1),
  ]),
  unreadMotion: EntryMotion(900, [
    EntryKeyframe(0, opacity: 0, y: 7, scale: .82),
    EntryKeyframe(.55, y: -1, scale: 1.05),
    EntryKeyframe(.78),
    EntryKeyframe(1),
  ], curve: Cubic(.22, .75, .3, 1)),
);

const _grimoire = MiniPhoneEntrySkin(
  bodyAsset: 'entry-arcane-grimoire-body',
  unreadAsset: 'entry-arcane-grimoire-unread',
  unreadRect: Rect.fromLTWH(17, 50, 5, 8),
  decorationAsset: 'entry-arcane-grimoire-decoration',
  decorationRect: Rect.fromLTWH(13, 18, 12, 12.5),
  musicOffset: Offset(11.75, 17.5),
  unreadGlow: true,
  arrivalMotion: EntryMotion(900, [
    EntryKeyframe(0),
    EntryKeyframe(.45, y: -3, rotation: -3, glow: 1),
    EntryKeyframe(.7, y: -1, rotation: 1),
    EntryKeyframe(1),
  ]),
);

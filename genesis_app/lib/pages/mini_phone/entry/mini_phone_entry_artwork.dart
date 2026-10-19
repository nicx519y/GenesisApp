import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shared/mini_phone_ui.dart';
import 'mini_phone_entry_motion.dart';
import 'mini_phone_entry_style.dart';

Widget entrySvg(
  String name, {
  double? width,
  double? height,
  Color? color,
  BoxFit fit = BoxFit.contain,
}) => SvgPicture.asset(
  'assets/mini_phone/icons/$name.svg',
  width: width,
  height: height,
  fit: fit,
  excludeFromSemantics: true,
  colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
);

/// One rendering pipeline for every skin; it has no style-specific branches or
/// session effects. Dynamic time/counts/avatars never come from sample SVG text.
class MiniPhoneEntryArtwork extends StatelessWidget {
  const MiniPhoneEntryArtwork({
    super.key,
    required this.skin,
    required this.unread,
    required this.showMusic,
    required this.playing,
    required this.arriving,
    required this.arrivalProgress,
    required this.musicProgress,
    required this.clockTime,
    required this.reducedMotion,
  });
  final MiniPhoneEntrySkin skin;
  final bool unread, showMusic, playing, arriving, reducedMotion;
  final double arrivalProgress, musicProgress;
  final String clockTime;

  @override
  Widget build(BuildContext context) {
    final elapsed = arrivalProgress * entryAvatarMotion.durationMs;
    final bodyFrame = arriving && !reducedMotion
        ? skin.arrivalMotion.atMilliseconds(elapsed)
        : const EntryKeyframe(1);
    final unreadFrame = arriving && !reducedMotion
        ? skin.unreadMotion?.atMilliseconds(elapsed) ?? const EntryKeyframe(1)
        : const EntryKeyframe(1);
    final musicFrame = !playing
        ? const EntryKeyframe(1, opacity: .55)
        : reducedMotion
        ? const EntryKeyframe(1)
        : entryMusicMotion.sample(musicProgress);
    Widget body({Color? color}) =>
        entrySvg(skin.bodyAsset, width: 34, height: 59, color: color);
    Widget glow(Widget child, double sigma) => ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
    final decoration = skin.decorationAsset;
    final clock = skin.clockRect;
    return bodyFrame.apply(
      SizedBox(
        width: 34,
        height: 57,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 3,
              child: glow(body(color: const Color(0x77000000)), 2),
            ),
            if (bodyFrame.glow > 0)
              Positioned(
                left: 0,
                top: 0,
                child: Opacity(
                  opacity: bodyFrame.glow,
                  child: glow(body(color: const Color(0x80FFFFFF)), 1.5),
                ),
              ),
            Positioned(left: 0, top: 0, child: body()),
            if (decoration != null && !showMusic) ...[
              if (unread && skin.unreadGlow)
                Positioned.fromRect(
                  rect: skin.decorationRect!,
                  child: glow(
                    entrySvg(decoration, color: const Color(0x55FFFFFF)),
                    1,
                  ),
                ),
              Positioned.fromRect(
                rect: skin.decorationRect!,
                child: entrySvg(decoration),
              ),
            ],
            if (clock != null)
              Positioned.fromRect(
                rect: clock,
                child: Center(
                  child: Text(
                    clockTime,
                    textScaler: TextScaler.noScaling,
                    style: miniStyle(
                      7,
                      FontWeight.w900,
                    ).copyWith(height: 1, letterSpacing: -.175),
                  ),
                ),
              ),
            if (unread)
              Positioned.fromRect(
                rect: skin.unreadRect,
                child: unreadFrame.apply(
                  entrySvg(skin.unreadAsset),
                  alignment: Alignment.bottomCenter,
                ),
              ),
            if (showMusic)
              Positioned(
                left: skin.musicOffset.dx,
                top: skin.musicOffset.dy,
                child: musicFrame.apply(
                  const MiniIcon('music-musical-note', size: 16),
                ),
              ),
          ],
        ),
      ),
      alignment: const Alignment(0, .7),
    );
  }
}

class MiniPhoneEntryBubble extends StatelessWidget {
  const MiniPhoneEntryBubble({
    super.key,
    this.avatar,
    this.playRequested,
    this.onTap,
  });
  final Widget? avatar;
  final bool? playRequested;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 36,
      height: 41,
      child: Stack(
        children: [
          entrySvg(
            avatar != null
                ? 'entry-avatar-bubble'
                : playRequested == true
                ? 'entry-pause-bubble'
                : 'entry-play-bubble',
            width: 36,
            height: 41,
            fit: BoxFit.fill,
          ),
          if (avatar != null)
            Positioned(
              left: 2,
              top: 2,
              width: 32,
              height: 32,
              child: ClipOval(child: avatar),
            ),
          if (avatar != null && playRequested != null)
            Positioned(
              right: 2,
              top: 18,
              child: Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                  color: Color(0xFF232228),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: MiniIcon(
                    playRequested! ? 'music-pause' : 'music-play',
                    size: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return child;
    final label = playRequested == true ? 'Pause music' : 'Play music';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        ),
      ),
    );
  }
}

class MiniPhoneEntryBadge extends StatelessWidget {
  const MiniPhoneEntryBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 17),
    height: 17,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: miniRed,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
    ),
    child: Center(
      child: Text(
        '$count',
        textScaler: TextScaler.noScaling,
        style: miniStyle(9, FontWeight.w700).copyWith(height: 1),
      ),
    ),
  );
}

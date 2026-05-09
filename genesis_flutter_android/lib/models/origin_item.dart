import 'package:flutter/material.dart';

@immutable
class OriginItem {
  const OriginItem({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.readCount,
    required this.likeCount,
    required this.gradient,
    required this.badgeText,
    required this.coverHeight,
    this.coverImageUrl = '',
  });

  final String title;
  final String subtitle;
  final List<String> tags;
  final String readCount;
  final String likeCount;
  final List<Color> gradient;
  final String badgeText;
  final double coverHeight;
  final String coverImageUrl;

  OriginItem copyWith({
    String? title,
    String? subtitle,
    List<String>? tags,
    String? readCount,
    String? likeCount,
    List<Color>? gradient,
    String? badgeText,
    double? coverHeight,
    String? coverImageUrl,
  }) {
    return OriginItem(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      tags: tags ?? this.tags,
      readCount: readCount ?? this.readCount,
      likeCount: likeCount ?? this.likeCount,
      gradient: gradient ?? this.gradient,
      badgeText: badgeText ?? this.badgeText,
      coverHeight: coverHeight ?? this.coverHeight,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}

const List<OriginItem> demoOriginItems = [
  OriginItem(
    title: '#Hogwarts',
    subtitle: '🧙 Enter the wizarding world',
    tags: ['Cheerful experience', 'Magic'],
    readCount: '1.3K',
    likeCount: '3.4M',
    gradient: [Color(0xFF0B2D6B), Color(0xFF6C2CF2)],
    badgeText: 'ENTER\nTHE\nWIZARDING\nWORLD',
    coverHeight: 168,
    coverImageUrl: 'https://picsum.photos/seed/hogwarts/800/1200',
  ),
  OriginItem(
    title: '#Werewolf and Vampire',
    subtitle: '🧛 Embrace the primal fury of the pack, or the cold elegance of the night?',
    tags: ['Werewolf', 'Vampire', 'Peace and Love'],
    readCount: '892',
    likeCount: '2.7M',
    gradient: [Color(0xFF0F3D2E), Color(0xFF7E1EE0)],
    badgeText: 'REALMS\nDIVIDED',
    coverHeight: 214,
    coverImageUrl: 'https://picsum.photos/seed/werewolf_vampire/800/1200',
  ),
  OriginItem(
    title: '#ALPHA Empire',
    subtitle: '💗 Four industry titans, one city, and a million ways to win their hearts.',
    tags: ['Billionare', 'Boss', 'Bully'],
    readCount: '2.3K',
    likeCount: '4.4M',
    gradient: [Color(0xFF1D2340), Color(0xFFB012F0)],
    badgeText: 'ALPHA\nEMPIRE',
    coverHeight: 238,
    coverImageUrl: 'https://picsum.photos/seed/alpha_empire/800/1200',
  ),
  OriginItem(
    title: '#Stellaris Wars',
    subtitle: 'The Galaxy is Burning. Will You Lead or Fall?',
    tags: ['Starwars', 'Destroyed Stellar'],
    readCount: '2.7K',
    likeCount: '6.1M',
    gradient: [Color(0xFF111827), Color(0xFF2563EB)],
    badgeText: 'STELLARIS\nWARS',
    coverHeight: 158,
    coverImageUrl: 'https://picsum.photos/seed/stellaris_wars/800/1200',
  ),
];

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../utils/genesis_image_resource.dart';

class CharactersList extends StatelessWidget {
  const CharactersList({super.key, required this.characters});

  final List<Map<String, dynamic>> characters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MyFlutterApp.userStar, size: 18),
            const SizedBox(width: 6),
            Text(
              'Characters (${characters.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < characters.length; i++)
          _CharacterListItem(
            character: characters[i],
            isLast: i == characters.length - 1,
          ),
      ],
    );
  }
}

class _CharacterListItem extends StatelessWidget {
  const _CharacterListItem({required this.character, required this.isLast});

  final Map<String, dynamic> character;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = character['name'] as String? ?? '';
    final subtitle = character['subtitle'] as String? ?? '';
    final tags = ((character['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final imageUrl = character['image'] as String? ?? '';
    final powerText = character['powerText'] as String? ?? '';

    return Column(
      children: [
        _CharacterTile(
          name: name,
          subtitle: subtitle,
          tags: tags,
          imageUrl: imageUrl,
          powerText: powerText,
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
          const SizedBox(height: 10),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.name,
    required this.subtitle,
    required this.tags,
    required this.imageUrl,
    required this.powerText,
  });

  final String name;
  final String subtitle;
  final List<String> tags;
  final String imageUrl;
  final String powerText;

  @override
  Widget build(BuildContext context) {
    final url = selectGenesisImageUrl(
      imageUrl,
      logicalWidth: 86,
      logicalHeight: 86,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
    final fallback = GenesisAvatarFallback(
      name: name,
      width: 86,
      height: 86,
      borderRadius: 6,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: url.isEmpty
                ? fallback
                : url.startsWith('assets/')
                ? Image.asset(
                    url,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    placeholder: (context, url) => fallback,
                    errorWidget: (context, url, error) => fallback,
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFF42C47),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

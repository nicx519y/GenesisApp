import 'package:flutter/material.dart';

class ProfileCollectionItemVm {
  const ProfileCollectionItemVm({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class ProfileCollectionList extends StatelessWidget {
  const ProfileCollectionList({
    super.key,
    required this.items,
    required this.emptyText,
  });

  final List<ProfileCollectionItemVm> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(
            fontSize: 22,
            color: Color(0xFF8A8A8A),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          ProfileCollectionListItem(item: items[index]),
    );
  }
}

class ProfileCollectionListItem extends StatelessWidget {
  const ProfileCollectionListItem({super.key, required this.item});

  final ProfileCollectionItemVm item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _ItemImage(url: item.imageUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6F6F6F),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xFFB5B5B5)),
          ],
        ),
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9C9C9C)),
    );
  }
}

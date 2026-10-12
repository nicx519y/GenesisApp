class MiniphoneInfo {
  const MiniphoneInfo({
    required this.backgroundImage,
    required this.wallpapers,
  });

  factory MiniphoneInfo.fromJson(Map<String, dynamic> json) {
    final background = json['background_image'];
    final images = json['default_background_images'];
    if (background is! String || images is! List) {
      throw const FormatException('Invalid MiniPhone background information');
    }
    return MiniphoneInfo(
      backgroundImage: background,
      wallpapers: List.unmodifiable(
        images.map((item) {
          if (item is! Map ||
              item['image_url'] is! String ||
              item['title'] is! String) {
            throw const FormatException('Invalid MiniPhone wallpaper');
          }
          return MiniphoneWallpaper(
            imageUrl: item['image_url'] as String,
            title: item['title'] as String,
          );
        }),
      ),
    );
  }

  final String backgroundImage;
  final List<MiniphoneWallpaper> wallpapers;
}

class MiniphoneWallpaper {
  const MiniphoneWallpaper({required this.imageUrl, required this.title});
  final String imageUrl;
  final String title;
}

bool isValidMiniphoneBackground(String value) {
  if (value.isEmpty) return true;
  final uri = Uri.tryParse(value);
  return value.length <= 512 &&
      value.trim() == value &&
      RegExp(
        r'^https?://[^/?#@\s]+(?:[/?#]|$)',
        caseSensitive: false,
      ).hasMatch(value) &&
      !RegExp(r'\s').hasMatch(value) &&
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.authority.contains('@');
}

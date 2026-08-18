class GenesisImageConfig {
  const GenesisImageConfig._();

  /// Maximum DPR used for CDN image sizing and target decode dimensions.
  static const double maxDevicePixelRatio = 1.5;

  /// Message-bubble avatars in location, private, and Origin preview chats.
  static const double chatAvatarMaxDevicePixelRatio = 2.4;

  /// Character avatars rendered over Tilemap locations.
  static const double tilemapAvatarMaxDevicePixelRatio = 2.4;
}

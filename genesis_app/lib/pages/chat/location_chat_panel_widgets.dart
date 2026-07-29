part of 'location_chat_page.dart';

class _LocationChatBackground extends StatelessWidget {
  const _LocationChatBackground({
    required this.imageUrl,
    required this.previewImageUrl,
    required this.color,
  });

  final String? imageUrl;
  final String? previewImageUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: color,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final url = _resolveLocationChatBackgroundUrl(
              imageUrl,
              previewImageUrl: previewImageUrl,
              logicalWidth: constraints.maxWidth,
              logicalHeight: constraints.maxHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            return _LocationChatBackgroundImage(url: url);
          },
        ),
      ),
    );
  }
}

String _resolveLocationChatBackgroundUrl(
  Object? imageUrl, {
  Object? previewImageUrl,
  required double? logicalWidth,
  required double? logicalHeight,
  required double devicePixelRatio,
}) {
  final selected = selectGenesisImageUrl(
    imageUrl,
    fallback: previewImageUrl,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  );
  final resolved = resolveAssetUrl(selected);
  if (resolved.isNotEmpty) return resolved;
  return _locationChatDefaultBackgroundAsset;
}

class _LocationChatBackgroundImage extends StatelessWidget {
  const _LocationChatBackgroundImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = url.trim();
    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.expand();
        },
      );
    }
    return GenesisStaticNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (_) => const SizedBox.expand(),
      errorWidget: (_, _) => const SizedBox.expand(),
    );
  }
}

@visibleForTesting
String resolveLocationChatBackgroundUrlForTesting({
  Object? imageUrl,
  Object? previewImageUrl,
  double logicalWidth = 390,
  double logicalHeight = 844,
  double devicePixelRatio = 1,
}) {
  return _resolveLocationChatBackgroundUrl(
    imageUrl,
    previewImageUrl: previewImageUrl,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  );
}

class _LocationChatComposerExtension extends StatelessWidget {
  const _LocationChatComposerExtension({
    required this.style,
    required this.child,
  });

  final ChatUiStyleConfig style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -_locationChatComposerBottomExtension,
          height: _locationChatComposerBottomExtension,
          child: DecoratedBox(
            decoration: BoxDecoration(color: _bottomExtensionColor(style)),
          ),
        ),
        child,
      ],
    );
  }

  Color _bottomExtensionColor(ChatUiStyleConfig style) {
    final gradient = style.composerBackgroundGradient;
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.last;
    }
    return style.composerBackgroundColor;
  }
}

class _LocationChatMeasuredComposer extends StatefulWidget {
  const _LocationChatMeasuredComposer({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double> onHeightChanged;

  @override
  State<_LocationChatMeasuredComposer> createState() =>
      _LocationChatMeasuredComposerState();
}

class _LocationChatMeasuredComposerState
    extends State<_LocationChatMeasuredComposer> {
  final _key = GlobalKey();
  double _lastHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _LocationChatMeasuredComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final context = _key.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final height = renderObject.size.height;
    if ((_lastHeight - height).abs() <= 0.5) return;
    _lastHeight = height;
    widget.onHeightChanged(height);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: SizeChangedLayoutNotifier(key: _key, child: widget.child),
    );
  }
}

class _LocationChatNewMessageNotice extends StatelessWidget {
  const _LocationChatNewMessageNotice({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1E1E24),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('location-chat-new-message-notice'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$count new message',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

String _firstMapString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _mapString(map, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _firstMapImageUrl(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (!map.containsKey(key)) continue;
    final resolved = asResolvedImageUrl(map[key], resolveAssetUrl);
    if (resolved.isNotEmpty) return resolved;
  }
  return '';
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> map) {
  return {
    for (final entry in map.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _chatroomIdentityKey(String? value) {
  return (value ?? '').trim().toLowerCase();
}

@visibleForTesting
bool locationChatMessageBelongsToCurrentRoleForTesting({
  required String messageUserId,
  required String messageSenderId,
  required Iterable<String> currentUserIds,
  required Iterable<String> currentSenderIds,
  required Iterable<Map<String, dynamic>> characters,
  required Iterable<Map<String, dynamic>> characterPositions,
}) {
  return _locationChatMessageBelongsToCurrentRole(
    messageUserId: messageUserId,
    messageSenderId: messageSenderId,
    currentUserIds: currentUserIds,
    currentSenderIds: currentSenderIds,
    characters: characters,
    characterPositions: characterPositions,
  );
}

bool _locationChatMessageBelongsToCurrentRole({
  required String messageUserId,
  required String messageSenderId,
  required Iterable<String> currentUserIds,
  required Iterable<String> currentSenderIds,
  required Iterable<Map<String, dynamic>> characters,
  required Iterable<Map<String, dynamic>> characterPositions,
}) {
  final identityKeys = <String>{
    ...currentUserIds.map(_chatroomIdentityKey),
    ...currentSenderIds.map(_chatroomIdentityKey),
  }..remove('');
  if (identityKeys.isEmpty) return false;

  for (final candidate in <Map<String, dynamic>>[
    ...characters,
    ...characterPositions,
  ]) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    final ownerKeys = <String>{
      for (final key in const ['player_uid', 'user_id', 'uid'])
        _chatroomIdentityKey(_mapString(character, key)),
    }..remove('');
    final characterKeys = <String>{
      for (final key in const ['character_id', 'char_id', 'id'])
        _chatroomIdentityKey(_mapString(character, key)),
    }..remove('');
    if (!ownerKeys.any(identityKeys.contains) &&
        !characterKeys.any(identityKeys.contains)) {
      continue;
    }
    identityKeys
      ..addAll(ownerKeys)
      ..addAll(characterKeys);
  }

  final messageUserIdKey = _chatroomIdentityKey(messageUserId);
  if (messageUserIdKey.isNotEmpty && identityKeys.contains(messageUserIdKey)) {
    return true;
  }
  final messageSenderIdKey = _chatroomIdentityKey(messageSenderId);
  return messageSenderIdKey.isNotEmpty &&
      identityKeys.contains(messageSenderIdKey);
}

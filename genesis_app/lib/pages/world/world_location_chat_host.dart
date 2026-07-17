// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/shared/location_chat_overlay_transition.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/location_tree.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../chat/location_chat_page.dart';
import 'world_map_data.dart';
import 'world_value_helpers.dart';

class WorldLocationChatPanelDescriptor {
  const WorldLocationChatPanelDescriptor({
    required this.locationId,
    required this.locationName,
    required this.backgroundImageUrl,
    required this.backgroundPreviewImageUrl,
    required this.isLeafLocation,
    this.localMessageLocationIds = const <String>[],
    this.recentChatLocationPathIds = const <String>[],
  });

  factory WorldLocationChatPanelDescriptor.fromNode(
    LocationTreeNode<Map<String, dynamic>> node,
  ) {
    final value = node.value;
    final locationId = node.id.trim();
    final valueLocationId = worldMapString(value, const ['location_id', 'id']);
    final pointId = worldMapString(value, const ['point_id']);
    return WorldLocationChatPanelDescriptor(
      locationId: locationId,
      locationName: worldMapString(value, const [
        'location_name',
        'name',
      ], fallback: locationId),
      backgroundImageUrl: worldLocationChatImageUrl(
        value,
        preferredKey: 'xl_url',
      ),
      backgroundPreviewImageUrl: '',
      isLeafLocation: node.children.isEmpty,
      localMessageLocationIds: worldOrderedNonEmptyStrings([
        pointId,
        locationId,
        valueLocationId,
      ]),
      recentChatLocationPathIds: worldOrderedNonEmptyStrings([locationId]),
    );
  }

  factory WorldLocationChatPanelDescriptor.fromLocation(
    Map<String, dynamic> location, {
    required bool isLeafLocation,
  }) {
    final locationId = worldMapString(location, const ['location_id', 'id']);
    final pointId = worldMapString(location, const ['point_id']);
    return WorldLocationChatPanelDescriptor(
      locationId: locationId,
      locationName: worldMapString(location, const [
        'location_name',
        'name',
      ], fallback: locationId),
      backgroundImageUrl: worldLocationChatImageUrl(
        location,
        preferredKey: 'xl_url',
      ),
      backgroundPreviewImageUrl: '',
      isLeafLocation: isLeafLocation,
      localMessageLocationIds: worldOrderedNonEmptyStrings([
        pointId,
        locationId,
      ]),
      recentChatLocationPathIds: worldOrderedNonEmptyStrings([locationId]),
    );
  }

  final String locationId;
  final String locationName;
  final String backgroundImageUrl;
  final String backgroundPreviewImageUrl;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
  final List<String> recentChatLocationPathIds;

  WorldLocationChatPanelDescriptor copyWith({
    String? locationId,
    String? locationName,
    String? backgroundImageUrl,
    String? backgroundPreviewImageUrl,
    bool? isLeafLocation,
    List<String>? localMessageLocationIds,
    List<String>? recentChatLocationPathIds,
  }) {
    return WorldLocationChatPanelDescriptor(
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundPreviewImageUrl:
          backgroundPreviewImageUrl ?? this.backgroundPreviewImageUrl,
      isLeafLocation: isLeafLocation ?? this.isLeafLocation,
      localMessageLocationIds:
          localMessageLocationIds ?? this.localMessageLocationIds,
      recentChatLocationPathIds:
          recentChatLocationPathIds ?? this.recentChatLocationPathIds,
    );
  }
}

class WorldLocationChatPageCache {
  final Map<String, WorldLocationChatPanelDescriptor> _descriptors =
      <String, WorldLocationChatPanelDescriptor>{};
  final Set<String> _cachedLocationIds = <String>{};
  final Set<String> _readyLocationIds = <String>{};
  final Map<String, String> _draftTextByLocation = <String, String>{};

  String activeLocationId = '';

  int get cachedPanelCount => _cachedLocationIds.length;

  Iterable<String> get cachedLocationIds =>
      _cachedLocationIds.where(_descriptors.containsKey);

  WorldLocationChatPanelDescriptor? get activeDescriptor =>
      _descriptors[activeLocationId];

  bool hasPanel(String locationId) => _cachedLocationIds.contains(locationId);

  bool isReady(String locationId) => _readyLocationIds.contains(locationId);

  void syncDescriptors(
    Map<String, WorldLocationChatPanelDescriptor> descriptors,
  ) {
    _descriptors
      ..clear()
      ..addAll(descriptors);
    _cachedLocationIds.addAll(
      descriptors.values
          .where((descriptor) => descriptor.isLeafLocation)
          .map((descriptor) => descriptor.locationId),
    );
    _cachedLocationIds.removeWhere((locationId) {
      return !descriptors.containsKey(locationId);
    });
    _readyLocationIds.removeWhere((locationId) {
      return !descriptors.containsKey(locationId);
    });
    _draftTextByLocation.removeWhere((locationId, _) {
      return !descriptors.containsKey(locationId);
    });
    if (!_descriptors.containsKey(activeLocationId)) {
      activeLocationId = '';
    }
  }

  void activate(WorldLocationChatPanelDescriptor descriptor) {
    _descriptors[descriptor.locationId] = descriptor;
    _cachedLocationIds.add(descriptor.locationId);
    activeLocationId = descriptor.locationId;
  }

  void deactivate() {
    activeLocationId = '';
  }

  WorldLocationChatPanelDescriptor? descriptorFor(String locationId) {
    return _descriptors[locationId];
  }

  bool markReady(String locationId) {
    return _readyLocationIds.add(locationId);
  }

  String draftTextFor(String locationId) {
    return _draftTextByLocation[locationId] ?? '';
  }

  void updateDraftText(String locationId, String text) {
    if (locationId.isEmpty) return;
    if (text.isEmpty) {
      _draftTextByLocation.remove(locationId);
      return;
    }
    _draftTextByLocation[locationId] = text;
  }

  void clear() {
    _descriptors.clear();
    _cachedLocationIds.clear();
    _readyLocationIds.clear();
    _draftTextByLocation.clear();
    activeLocationId = '';
  }

  void dispose() {
    clear();
  }
}

class WorldLocationChatRouterHost extends StatefulWidget {
  const WorldLocationChatRouterHost({
    required this.worldId,
    required this.chatroom,
    required this.cache,
    required this.onBack,
    required this.onPanelReady,
    required this.isMessageQueueInitializationCovered,
  });

  final String worldId;
  final WorldChatroomService? chatroom;
  final WorldLocationChatPageCache cache;
  final VoidCallback onBack;
  final ValueChanged<String> onPanelReady;
  final bool Function(String locationId) isMessageQueueInitializationCovered;

  @override
  State<WorldLocationChatRouterHost> createState() =>
      WorldLocationChatRouterHostState();
}

class WorldLocationChatRouterHostState
    extends State<WorldLocationChatRouterHost> {
  String _displayLocationId = '';

  @override
  void initState() {
    super.initState();
    _syncDisplayLocationId();
  }

  @override
  void didUpdateWidget(WorldLocationChatRouterHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDisplayLocationId();
  }

  void _syncDisplayLocationId() {
    final activeLocationId = widget.cache.activeLocationId;
    if (activeLocationId.isNotEmpty) {
      _displayLocationId = activeLocationId;
    }
  }

  void _handleDismissed() {
    if (_displayLocationId.isEmpty) return;
    setState(() => _displayLocationId = '');
  }

  @override
  Widget build(BuildContext context) {
    final activeLocationId = widget.cache.activeLocationId;
    final activeDescriptor = widget.cache.activeDescriptor;
    final displayLocationId = activeLocationId.isNotEmpty
        ? activeLocationId
        : _displayLocationId;
    final cachedIds = widget.cache.cachedLocationIds.toList(growable: false);
    final showSkeleton =
        activeLocationId.isNotEmpty &&
        activeDescriptor != null &&
        !widget.cache.isReady(activeLocationId);
    final active = activeLocationId.isNotEmpty;

    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: LocationChatOverlayTransition(
          active: active,
          maintainChildOnDismiss: true,
          onDismissed: _handleDismissed,
          child: Stack(
            children: [
              for (final descriptor
                  in cachedIds
                      .map(widget.cache.descriptorFor)
                      .whereType<WorldLocationChatPanelDescriptor>())
                _buildCachedPage(
                  descriptor,
                  displayLocationId: displayLocationId,
                  activeLocationId: activeLocationId,
                ),
              if (showSkeleton)
                Positioned.fill(
                  child: _LocationChatPanelSkeleton(
                    title: activeDescriptor.locationName,
                    onBack: widget.onBack,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCachedPage(
    WorldLocationChatPanelDescriptor descriptor, {
    required String displayLocationId,
    required String activeLocationId,
  }) {
    final active = descriptor.locationId == activeLocationId;
    final visible = descriptor.locationId == displayLocationId;
    final ready = widget.cache.isReady(descriptor.locationId);
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: Offstage(
          offstage: !visible,
          child: Opacity(
            opacity: visible && ready ? 1 : 0,
            child: TickerMode(
              enabled: visible,
              child: SizedBox.expand(
                child: WorldLocationChatNestedRouterPage(
                  key: ValueKey(
                    'world-location-chat-router-${descriptor.locationId}',
                  ),
                  worldId: widget.worldId,
                  chatroom: widget.chatroom,
                  descriptor: descriptor,
                  active: active,
                  messageQueueInitializationCovered: widget
                      .isMessageQueueInitializationCovered(
                        descriptor.locationId,
                      ),
                  onBack: widget.onBack,
                  onInitialContentReady: () =>
                      widget.onPanelReady(descriptor.locationId),
                  initialDraftText: widget.cache.draftTextFor(
                    descriptor.locationId,
                  ),
                  onDraftTextChanged: (text) {
                    widget.cache.updateDraftText(descriptor.locationId, text);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorldLocationChatNestedRouterPage extends StatelessWidget {
  const WorldLocationChatNestedRouterPage({
    super.key,
    required this.worldId,
    required this.chatroom,
    required this.descriptor,
    required this.active,
    required this.onBack,
    required this.onInitialContentReady,
    required this.initialDraftText,
    required this.onDraftTextChanged,
    required this.messageQueueInitializationCovered,
  });

  final String worldId;
  final WorldChatroomService? chatroom;
  final WorldLocationChatPanelDescriptor descriptor;
  final bool active;
  final VoidCallback onBack;
  final VoidCallback onInitialContentReady;
  final String initialDraftText;
  final ValueChanged<String> onDraftTextChanged;
  final bool messageQueueInitializationCovered;

  @override
  Widget build(BuildContext context) {
    final routeName = 'world_location_chat/$worldId/${descriptor.locationId}';
    return Navigator(
      pages: [
        MaterialPage<void>(
          key: ValueKey(routeName),
          name: routeName,
          child: LocationChatPanel(
            key: ValueKey('world-location-chat-${descriptor.locationId}'),
            worldId: worldId,
            locationId: descriptor.locationId,
            locationName: descriptor.locationName,
            backgroundImageUrl: descriptor.backgroundImageUrl,
            backgroundPreviewImageUrl: descriptor.backgroundPreviewImageUrl,
            isLeafLocation: descriptor.isLeafLocation,
            localMessageLocationIds: descriptor.localMessageLocationIds,
            recentChatLocationPathIds: descriptor.recentChatLocationPathIds,
            service: chatroom,
            active: active,
            leaveOnInactive: false,
            messageQueueInitializationCovered:
                messageQueueInitializationCovered,
            systemUiOverlayStyle: kChatDarkHeaderSystemUiOverlayStyle,
            style: kLocationChatStyle,
            onBack: onBack,
            onInitialContentReady: onInitialContentReady,
            initialDraftText: initialDraftText,
            onDraftTextChanged: onDraftTextChanged,
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

class _LocationChatPanelSkeleton extends StatelessWidget {
  const _LocationChatPanelSkeleton({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle;
    return GenesisBottomSystemBarStyleScope(
      style: GenesisBottomSystemBarStyle(color: style.composerBackgroundColor),
      child: ColoredBox(
        color: style.conversationBackgroundColor,
        child: Column(
          children: [
            ChatHeader(
              title: '$title (1)',
              subtitle: 'Loading',
              connected: false,
              connecting: true,
              onBack: onBack,
              showMoreButton: false,
              style: style,
            ),
            Expanded(child: _LocationChatMessageSkeletonList(style: style)),
            _LocationChatComposerSkeleton(style: style),
          ],
        ),
      ),
    );
  }
}

class _LocationChatMessageSkeletonList extends StatelessWidget {
  const _LocationChatMessageSkeletonList({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: style.messageListPadding,
      child: Column(
        children: [
          const Spacer(),
          _LocationChatDateSkeleton(style: style),
          _LocationChatOtherMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.62,
            lineWidths: const [0.74, 0.46],
          ),
          _LocationChatSelfMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.50,
            lineWidths: const [0.68],
          ),
          _LocationChatOtherMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.70,
            lineWidths: const [0.86, 0.58],
            showAiBadge: true,
          ),
          SizedBox(height: style.topTitleEmptyHeight),
        ],
      ),
    );
  }
}

class _LocationChatDateSkeleton extends StatelessWidget {
  const _LocationChatDateSkeleton({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.dateDividerBottomPadding),
      child: const Center(
        child: _LocationChatSkeletonBone(
          width: 72,
          height: 10,
          radius: 5,
          color: Color(0x33777777),
        ),
      ),
    );
  }
}

class _LocationChatOtherMessageSkeleton extends StatelessWidget {
  const _LocationChatOtherMessageSkeleton({
    required this.style,
    required this.bubbleWidthFactor,
    required this.lineWidths,
    this.showAiBadge = false,
  });

  final ChatUiStyleConfig style;
  final double bubbleWidthFactor;
  final List<double> lineWidths;
  final bool showAiBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ChatAvatar(
                label: '',
                colors: style.otherAvatarColors,
                style: style,
              ),
              if (showAiBadge)
                Positioned(
                  right: -8,
                  top: -9,
                  child: ChatAiBadge(style: style),
                ),
            ],
          ),
          SizedBox(width: style.avatarBubbleGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (style.showSenderNameAboveOtherBubble) ...[
                  const _LocationChatSkeletonBone(
                    width: 76,
                    height: 12,
                    radius: 6,
                    color: Color(0x33222222),
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                ],
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: bubbleWidthFactor,
                  child: _LocationChatBubbleSkeleton(
                    style: style,
                    color: style.otherBubbleColor,
                    lineColor: const Color(0xFFE5E8EC),
                    lineWidths: lineWidths,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: style.avatarSize + style.avatarBubbleGap),
        ],
      ),
    );
  }
}

class _LocationChatSelfMessageSkeleton extends StatelessWidget {
  const _LocationChatSelfMessageSkeleton({
    required this.style,
    required this.bubbleWidthFactor,
    required this.lineWidths,
  });

  final ChatUiStyleConfig style;
  final double bubbleWidthFactor;
  final List<double> lineWidths;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: style.avatarSize + style.avatarBubbleGap),
          Flexible(
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: bubbleWidthFactor,
              child: _LocationChatBubbleSkeleton(
                style: style,
                color: style.selfBubbleColor,
                lineColor: const Color(0x661A6B28),
                lineWidths: lineWidths,
              ),
            ),
          ),
          SizedBox(width: style.avatarBubbleGap),
          ChatAvatar(label: '', colors: style.selfAvatarColors, style: style),
        ],
      ),
    );
  }
}

class _LocationChatBubbleSkeleton extends StatelessWidget {
  const _LocationChatBubbleSkeleton({
    required this.style,
    required this.color,
    required this.lineColor,
    required this.lineWidths,
  });

  final ChatUiStyleConfig style;
  final Color color;
  final Color lineColor;
  final List<double> lineWidths;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(style.bubbleBorderRadius),
      ),
      child: Padding(
        padding: style.bubblePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lineWidths.length; i += 1) ...[
              _LocationChatSkeletonBone(
                widthFactor: lineWidths[i],
                height: 12,
                radius: 6,
                color: lineColor,
              ),
              if (i != lineWidths.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationChatComposerSkeleton extends StatelessWidget {
  const _LocationChatComposerSkeleton({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
    return Container(
      padding: style.composerPadding.copyWith(
        bottom: style.composerPadding.bottom + bottomInset,
      ),
      color: style.composerBackgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: style.inputMinHeight,
                maxHeight: style.inputMaxHeight,
              ),
              decoration: BoxDecoration(
                color: style.inputBackgroundColor,
                borderRadius: BorderRadius.circular(style.inputBorderRadius),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: style.inputHorizontalPadding,
                  vertical: style.inputVerticalPadding,
                ),
                child: const _LocationChatSkeletonBone(
                  widthFactor: 0.34,
                  height: 14,
                  radius: 7,
                  color: Color(0xFFE5E8EC),
                ),
              ),
            ),
          ),
          SizedBox(width: style.composerActionGap),
          DecoratedBox(
            decoration: BoxDecoration(
              color: style.composerSendButtonDisabledColor,
              borderRadius: BorderRadius.circular(
                style.composerSendButtonBorderRadius,
              ),
            ),
            child: SizedBox(
              width: style.composerSendButtonWidth,
              height: style.composerSendButtonHeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChatSkeletonBone extends StatelessWidget {
  const _LocationChatSkeletonBone({
    this.width,
    this.widthFactor,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: child,
    );
  }
}

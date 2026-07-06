part of 'origin_world_page.dart';

class _OriginPendingLaunchWaitOverlay extends StatelessWidget {
  const _OriginPendingLaunchWaitOverlay({
    required this.avatars,
    required this.onBackPressed,
  });

  final List<GenesisGenerationWaitAvatar> avatars;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return GenesisGenerationWaitOverlay(
      title: 'Launching your Worldo',
      characterAvatars: avatars,
      contentMinHeight: GenesisGenerationWaitOverlay.perspectiveContentHeight,
      onBackPressed: onBackPressed,
    );
  }
}

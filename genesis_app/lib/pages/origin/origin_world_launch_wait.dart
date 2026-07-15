part of 'origin_world_page.dart';

const String _originLaunchWaitTitle = 'Launching the Worldo';
const String _originLaunchWaitMessage =
    'In world, click the map, enter the location, and start interacting with the characters to move the world forward.';

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
      title: _originLaunchWaitTitle,
      message: _originLaunchWaitMessage,
      characterAvatars: avatars,
      onBackPressed: onBackPressed,
    );
  }
}

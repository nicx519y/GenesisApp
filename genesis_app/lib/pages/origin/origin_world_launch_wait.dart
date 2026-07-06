part of 'origin_world_page.dart';

class _OriginPendingLaunchWaitOverlay extends StatelessWidget {
  const _OriginPendingLaunchWaitOverlay({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return GenesisGenerationWaitOverlay(onBackPressed: onBackPressed);
  }
}

part of 'home_page.dart';

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.activationListenable,
    required this.isActiveListenable,
    required this.isFirstPageViewReported,
    required this.onFirstPageViewReady,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    required this.initialRequestMetricWindow,
    required this.initialMyWorldsRenderOperation,
    required this.initialMyWorldsRequestAttempt,
    this.initialMyWorldsData,
  });

  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool>? isActiveListenable;
  final bool Function(String action)? isFirstPageViewReported;
  final void Function(String action)? onFirstPageViewReady;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final Duration initialRequestMetricWindow;
  final FirebasePerformanceOperation? initialMyWorldsRenderOperation;
  final int initialMyWorldsRequestAttempt;
  final Map<String, dynamic>? initialMyWorldsData;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Column(
        children: [
          const _HomeHeader(),
          Expanded(
            child: _MyWorldFeed(
              index: 0,
              activationListenable: activationListenable,
              isActiveListenable: isActiveListenable,
              isFirstPageViewReported: isFirstPageViewReported,
              onFirstPageViewReady: onFirstPageViewReady,
              networkRequestsAllowed: networkRequestsAllowed,
              keepInitialNetworkFailureLoading:
                  keepInitialNetworkFailureLoading,
              initialRequestMetricWindow: initialRequestMetricWindow,
              initialPageData: initialMyWorldsData,
              initialPageRenderOperation: initialMyWorldsRenderOperation,
              initialPageRequestAttempt: initialMyWorldsRequestAttempt,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: context.genesisColors.pageBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: SizedBox(
          height: kGenesisTopBarHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Home',
                style: GenesisTypography.pageTitle.copyWith(
                  color: context.genesisColors.foregroundStrong,
                ),
              ),
              const Spacer(),
              _HomeSearchSquare(
                onTap: () {
                  Navigator.of(context).pushNamed(RouteNames.search);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSearchSquare extends StatelessWidget {
  const _HomeSearchSquare({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Semantics(
      button: true,
      label: 'Search',
      child: GestureDetector(
        key: const ValueKey<String>('home-search-square'),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.controlMuted,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            searchIconAsset,
            width: 15,
            height: 15,
            colorFilter: ColorFilter.mode(
              colors.foregroundStrong,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

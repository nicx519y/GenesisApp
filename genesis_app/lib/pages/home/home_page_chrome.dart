part of 'home_page.dart';

class _HomeInitialLoadingScaffold extends StatelessWidget {
  const _HomeInitialLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: HomePage.tabs.length,
      initialIndex: HomePage.myWorldsTabIndex,
      child: const Column(
        children: [
          _HomeHeader(),
          SizedBox(height: 4),
          Expanded(child: GenesisListLoadingSkeleton.popularOriginList()),
        ],
      ),
    );
  }
}

class _HomeTabScaffold extends StatelessWidget {
  const _HomeTabScaffold({
    required this.initialIndex,
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

  final int initialIndex;
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
      key: ValueKey<int>(initialIndex),
      length: HomePage.tabs.length,
      initialIndex: initialIndex,
      child: Column(
        children: [
          const _HomeHeader(),
          const SizedBox(height: 4),
          Expanded(
            child: _HomeTabView(
              activationListenable: activationListenable,
              isActiveListenable: isActiveListenable,
              isFirstPageViewReported: isFirstPageViewReported,
              onFirstPageViewReady: onFirstPageViewReady,
              networkRequestsAllowed: networkRequestsAllowed,
              keepInitialNetworkFailureLoading:
                  keepInitialNetworkFailureLoading,
              initialRequestMetricWindow: initialRequestMetricWindow,
              initialMyWorldsData: initialMyWorldsData,
              initialMyWorldsRenderOperation: initialMyWorldsRenderOperation,
              initialMyWorldsRequestAttempt: initialMyWorldsRequestAttempt,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs({this.showSelectedState = true});

  final bool showSelectedState;

  @override
  Widget build(BuildContext context) {
    final unselectedColor = showSelectedState
        ? null
        : context.genesisColors.navigationUnselected;
    final unselectedStyle = showSelectedState ? null : GenesisTypography.body;
    return GenesisTabBar(
      labels: HomePage.tabs,
      verticalPadding: 0,
      tabAlignment: TabAlignment.center,
      labelColor: unselectedColor,
      unselectedLabelColor: unselectedColor,
      labelStyle: unselectedStyle,
      unselectedLabelStyle: unselectedStyle,
      indicatorColor: showSelectedState ? null : Colors.transparent,
      indicatorMatchesLabelWidth: true,
    );
  }
}

class _HomeTabView extends StatelessWidget {
  const _HomeTabView({
    this.activationListenable,
    this.isActiveListenable,
    this.isFirstPageViewReported,
    this.onFirstPageViewReady,
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
    // 9l is a single list; the Popular feed is no longer reachable from Home.
    return TabBarView(
      children: [
        _MyWorldFeed(
          index: 0,
          activationListenable: activationListenable,
          isActiveListenable: isActiveListenable,
          isFirstPageViewReported: isFirstPageViewReported,
          onFirstPageViewReady: onFirstPageViewReady,
          networkRequestsAllowed: networkRequestsAllowed,
          keepInitialNetworkFailureLoading: keepInitialNetworkFailureLoading,
          initialRequestMetricWindow: initialRequestMetricWindow,
          initialPageData: initialMyWorldsData,
          initialPageRenderOperation: initialMyWorldsRenderOperation,
          initialPageRequestAttempt: initialMyWorldsRequestAttempt,
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 9l header: the page title on the left, a 34px search square on the
        // right. No wordmark and no inline search field — those belong to the
        // Worlds feed (9h), which has its own full-width search.
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

/// 9l: the 34px search square that replaces the inline search field on Home.
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

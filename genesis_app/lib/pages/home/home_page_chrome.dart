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
          _HomeTabs(showSelectedState: false),
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
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    required this.initialRequestMetricWindow,
    required this.initialMyWorldsRenderOperation,
    required this.initialMyWorldsRequestAttempt,
    this.initialMyWorldsData,
  });

  final int initialIndex;
  final ValueListenable<int>? activationListenable;
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
          const _HomeTabs(),
          Expanded(
            child: _HomeTabView(
              activationListenable: activationListenable,
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
    final uiTheme = GenesisUiTheme.of(context);
    final unselectedColor = showSelectedState
        ? null
        : uiTheme.tabUnselectedColor;
    final unselectedStyle = showSelectedState ? null : uiTheme.bodyStyle;
    return GenesisTabBar(
      labels: HomePage.tabs,
      verticalPadding: 0,
      tabAlignment: TabAlignment.center,
      labelColor: unselectedColor,
      unselectedLabelColor: unselectedColor,
      labelStyle: unselectedStyle,
      unselectedLabelStyle: unselectedStyle,
      indicatorColor: showSelectedState ? null : Colors.transparent,
    );
  }
}

class _HomeTabView extends StatelessWidget {
  const _HomeTabView({
    this.activationListenable,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    required this.initialRequestMetricWindow,
    required this.initialMyWorldsRenderOperation,
    required this.initialMyWorldsRequestAttempt,
    this.initialMyWorldsData,
  });

  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final Duration initialRequestMetricWindow;
  final FirebasePerformanceOperation? initialMyWorldsRenderOperation;
  final int initialMyWorldsRequestAttempt;
  final Map<String, dynamic>? initialMyWorldsData;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _MyWorldFeed(
          index: 0,
          activationListenable: activationListenable,
          networkRequestsAllowed: networkRequestsAllowed,
          keepInitialNetworkFailureLoading: keepInitialNetworkFailureLoading,
          initialRequestMetricWindow: initialRequestMetricWindow,
          initialPageData: initialMyWorldsData,
          initialPageRenderOperation: initialMyWorldsRenderOperation,
          initialPageRequestAttempt: initialMyWorldsRequestAttempt,
        ),
        _PopularOriginFeed(
          index: 1,
          activationListenable: activationListenable,
          networkRequestsAllowed: networkRequestsAllowed,
          keepInitialNetworkFailureLoading: keepInitialNetworkFailureLoading,
          initialRequestMetricWindow: initialRequestMetricWindow,
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
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kGenesisTopBarHeight,
          child: Transform.translate(
            offset: const Offset(0, 5),
            child: Row(
              children: [
                const GenesisLogo(height: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: GenesisSearchField(
                    variant: GenesisSearchFieldVariant.compact,
                    hintText: 'Explore',
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.search);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

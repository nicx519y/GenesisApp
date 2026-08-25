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
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kGenesisTopBarHeight + 4,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: kGenesisTopBarHeight,
              child: Transform.translate(
                offset: const Offset(0, 5),
                child: Row(
                  children: [
                    const GenesisLogo(height: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchBarPlaceholder(
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
        ),
      ),
    );
  }
}

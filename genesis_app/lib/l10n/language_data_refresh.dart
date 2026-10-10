import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app/debug_page_tracker.dart';
import 'app_language_controller.dart';

/// Keeps page state intact; reloads stale data only while the page is visible.
mixin LanguageDataRefresh<T extends StatefulWidget> on State<T> {
  ValueListenable<bool>? get languagePageActive => null;
  bool get languageSectionVisible => true;
  bool get languageDataLoading => false;
  bool get languageRefreshSucceeded => true;
  bool get languageDataStale =>
      _loadedLanguageRevision != appLanguageController.dataRevision;
  FutureOr<void> refreshLanguageData();

  late int _loadedLanguageRevision;
  bool _languageRefreshScheduled = false;
  bool _languageRefreshRunning = false;
  ValueListenable<bool>? _languageActive;
  PageRoute<dynamic>? _languageRoute;
  late final _LanguageRouteListener _languageRouteListener;

  @override
  void initState() {
    super.initState();
    _loadedLanguageRevision = appLanguageController.dataRevision;
    _languageRouteListener = _LanguageRouteListener(checkLanguageData);
    appLanguageController.addListener(checkLanguageData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _languageRoute)) {
      genesisPageRouteObserver.unsubscribe(_languageRouteListener);
      _languageRoute = route;
      genesisPageRouteObserver.subscribe(_languageRouteListener, route);
    }
    _bindLanguageActivation();
    checkLanguageData();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindLanguageActivation();
    checkLanguageData();
  }

  void _bindLanguageActivation() {
    final active = languagePageActive;
    if (identical(active, _languageActive)) return;
    _languageActive?.removeListener(checkLanguageData);
    _languageActive = active;
    active?.addListener(checkLanguageData);
  }

  bool get _languageVisible =>
      (_languageRoute?.isCurrent ?? true) &&
      (_languageActive?.value ?? true) &&
      languageSectionVisible;

  void checkLanguageData() {
    if (!mounted ||
        _languageRefreshScheduled ||
        _languageRefreshRunning ||
        languageDataLoading ||
        _loadedLanguageRevision == appLanguageController.dataRevision) {
      return;
    }
    _languageRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _languageRefreshScheduled = false;
      if (!mounted ||
          !_languageVisible ||
          _languageRefreshRunning ||
          languageDataLoading ||
          _loadedLanguageRevision == appLanguageController.dataRevision) {
        return;
      }
      final revision = appLanguageController.dataRevision;
      _languageRefreshRunning = true;
      try {
        await refreshLanguageData();
        if (languageRefreshSucceeded) {
          _loadedLanguageRevision = revision;
        }
      } catch (error) {
        // Page loaders retain their existing error/retry UI.
        debugPrint('[Language] Page refresh failed: $error');
      } finally {
        _languageRefreshRunning = false;
        if (mounted && revision != appLanguageController.dataRevision) {
          checkLanguageData();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    appLanguageController.removeListener(checkLanguageData);
    _languageActive?.removeListener(checkLanguageData);
    genesisPageRouteObserver.unsubscribe(_languageRouteListener);
    super.dispose();
  }
}

class _LanguageRouteListener extends RouteAware {
  _LanguageRouteListener(this.check);
  final VoidCallback check;
  @override
  void didPush() => check();
  @override
  void didPopNext() => check();
}

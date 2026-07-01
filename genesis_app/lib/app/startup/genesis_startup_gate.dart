import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/common/genesis_modal_routes.dart';
import '../../components/genesis_logo.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../platform/privacy/app_tracking_transparency_service.dart';
import '../../ui/genesis_ui.dart';
import '../bootstrap/app_bootstrap.dart';
import '../bootstrap/service_registry.dart';
import '../config/app_config.dart';
import '../genesis_app.dart';
import '../telemetry/genesis_telemetry.dart';

typedef TrackingAuthorizationRequester =
    Future<AppTrackingAuthorizationStatus> Function();

class GenesisStartupGate extends StatefulWidget {
  const GenesisStartupGate({
    super.key,
    required this.services,
    required this.config,
    required this.appVersion,
    required this.startedAt,
    this.primeNetworkPermission = AppBootstrap.primeNetworkPermission,
    this.ensureFirebasePerformanceMonitoring =
        AppBootstrap.ensureFirebasePerformanceMonitoring,
    this.requestTrackingAuthorization =
        AppTrackingTransparencyService.requestAuthorization,
    this.warmUp = AppBootstrap.warmUp,
  });

  final AppServices services;
  final AppConfig config;
  final AppVersionInfo appVersion;
  final DateTime startedAt;
  final Future<void> Function(AppServices services) primeNetworkPermission;
  final Future<void> Function() ensureFirebasePerformanceMonitoring;
  final TrackingAuthorizationRequester requestTrackingAuthorization;
  final Future<void> Function(AppServices services) warmUp;

  @override
  State<GenesisStartupGate> createState() => _GenesisStartupGateState();
}

class _GenesisStartupGateState extends State<GenesisStartupGate>
    with WidgetsBindingObserver {
  var _ready = false;
  AppLifecycleState? _lifecycleState;
  Completer<void>? _resumedCompleter;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupSequence());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumedCompleter?.complete();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _resumedCompleter?.complete();
      _resumedCompleter = null;
    }
  }

  Future<void> _runStartupSequence() async {
    AppTrackingAuthorizationStatus trackingAuthorizationStatus =
        AppTrackingAuthorizationStatus.notSupported;
    try {
      GenesisSystemUiChrome.applyDefault();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await widget.primeNetworkPermission(widget.services);
        await _waitForSystemDialogToClose();
      }
      trackingAuthorizationStatus = await widget.requestTrackingAuthorization();
      await _waitForSystemDialogToClose();
      await widget.ensureFirebasePerformanceMonitoring();
      await GenesisTelemetry.initialize(
        config: widget.config,
        deviceIdService: widget.services.deviceId,
        appVersion: widget.appVersion,
        trackingEnabled: trackingAuthorizationStatus.allowsTracking,
      );
      WidgetsBinding.instance.addObserver(
        GenesisTelemetryLifecycleObserver(startedAt: widget.startedAt),
      );
      GenesisSystemUiChrome.applyDefault();
    } catch (error, stackTrace) {
      debugPrint('[StartupGate] startup sequence failed: $error');
      debugPrint('[StartupGate] stacktrace:\n$stackTrace');
    }
    if (!mounted) return;
    setState(() => _ready = true);
    unawaited(widget.warmUp(widget.services));
  }

  Future<void> _waitForSystemDialogToClose() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_lifecycleState == AppLifecycleState.resumed ||
        _lifecycleState == null) {
      return;
    }
    final completer = _resumedCompleter ?? Completer<void>();
    _resumedCompleter = completer;
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return GenesisApp(services: widget.services);
    }
    return MaterialApp(
      title: 'Worldo',
      debugShowCheckedModeBanner: false,
      theme: GenesisTheme.light(),
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
      home: const _GenesisStartupSplashPage(),
    );
  }
}

class _GenesisStartupSplashPage extends StatelessWidget {
  const _GenesisStartupSplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: GenesisLogo(height: 72)),
    );
  }
}

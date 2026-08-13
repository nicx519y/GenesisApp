import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/gateway_auth.dart';
import 'package:genesis_flutter_android/network/genesis_http_cache_manager.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';

import '../../app/agent_control/agent_control_status.dart';
import '../../app/config/app_endpoint_overrides.dart';
import '../../app/config/app_config.dart';
import '../../app/debug_floating_button_visibility.dart';
import '../../app/debug_page_tracker.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_bottom_sheet_panel.dart';
import '../../components/common/genesis_generation_wait_overlay.dart';
import '../../components/gems/gem_purchase_bottom_sheet.dart';
import '../../components/gems/gem_purchase_catalog.dart';
import '../../components/gems/daily_check_in_dialog.dart';
import '../../components/genesis_logo.dart';
import '../../components/page_header.dart';
import '../../components/tilemap/tilemap_settings_button_visibility.dart';
import '../../app/gems/gem_wallet_store.dart';
import '../../network/genesis_api.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/gem_product.dart';
import '../../network/models/gem_wallet.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/billing_service.dart';
import '../../routers/app_router.dart';
import '../gems/gem_wallet_page.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';

part 'developer_endpoint_actions.dart';
part 'developer_previews.dart';
part 'developer_components.dart';

const String _buildModeLabel = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

const String _launchPreviewOriginId = 'o_G7DBQM';
const String _launchPreviewWaitTitle = 'Launching the Worldo';
const String _launchPreviewWaitMessage =
    'In world, click the map, enter the location, and start interacting with the characters to move the world forward.';
const String _progressPreviewWaitTitle = 'Progressing the World';
const String _progressPreviewWaitMessage =
    'Compressing recent memories\n'
    'Advancing the world timeline\n'
    'Generating the next story beat\n'
    'Updating character locations';
const List<String> _creatingPreviewWaitLines = [
  'Originator',
  'Eve',
  'A floating city where every district changes its laws at sunrise, and every resident keeps a private map of the rules they trust.',
  'Magic behaves like public infrastructure. Promises, debts, weather, and streetlights all run through the same civic engine.',
  'Mira: Exiled route-maker. Patient, skeptical, and protective of anyone who admits they are lost.',
  'Jon: Archive courier. Restless, charming, and far too willing to trade secrets for a shortcut.',
];

const List<String> _developerPageTabs = <String>[
  'basic',
  'test',
  'network',
  'websocket',
  'log',
];

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: 'Developer page'),
      body: const SafeArea(child: DeveloperPageContent()),
    );
  }
}

class DeveloperPageSheet extends StatelessWidget {
  const DeveloperPageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GenesisBottomSheetPanel(
          key: const ValueKey<String>('developer-page-sheet'),
          title: 'Developer page',
          height: constraints.maxHeight,
          trailing: GenesisBottomSheetCloseButton(
            buttonKey: const ValueKey<String>('developer-page-sheet-close'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleBottomSpacing: 12,
          child: DeveloperPageContent(
            dismissBeforePreview: true,
            onDismissBeforePreview: () async {
              await Navigator.of(context).maybePop();
            },
          ),
        );
      },
    );
  }
}

class DeveloperPageContent extends StatefulWidget {
  const DeveloperPageContent({
    super.key,
    this.dismissBeforePreview = false,
    this.onDismissBeforePreview,
  });

  final bool dismissBeforePreview;
  final Future<void> Function()? onDismissBeforePreview;

  @override
  State<DeveloperPageContent> createState() => _DeveloperPageContentState();
}

class _DeveloperPageContentState extends State<DeveloperPageContent> {
  static const double _itemGap = 8;
  static const String _productionEndpointHost = 'api.worldo.ai';
  static const String _testEndpointHost = 'dev.hushie.ai';
  static final String _defaultEndpointHost =
      AppEndpointOverrideStore.displayDomain(GenesisApi.defaultApiBaseUrl);

  late final Future<DeviceIdDiagnostics> _deviceIdDiagnosticsFuture;
  late final Future<AppVersionInfo> _appVersionFuture;
  late final Future<_DeveloperAccountIdentity> _accountIdentityFuture;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _gatewayApiBaseUrlController;
  late final TextEditingController _chatroomWsBaseUrlController;
  bool _clearingDirectMessageCache = false;
  bool _clearingImageCache = false;
  bool _clearingGatewayAuth = false;
  bool _verifyingGatewaySignature = false;
  bool _loadingEndpointOverrides = true;
  bool _savingEndpointOverrides = false;
  bool _loadingTilemapSettingsButtonVisibility = true;
  bool _savingTilemapSettingsButtonVisibility = false;
  bool _showTilemapSettingsButton = tilemapSettingsButtonVisibility.value;
  bool _dailyCheckInPreviewClaimed = false;
  String? _gatewaySignatureVerifyResult;

  @override
  void initState() {
    super.initState();
    final deviceId = AppServicesScope.read(context).deviceId;
    _deviceIdDiagnosticsFuture = deviceId is DeviceIdDiagnosticsService
        ? (deviceId as DeviceIdDiagnosticsService).getDeviceIdDiagnostics()
        : deviceId.getDeviceId().then(
            (value) => DeviceIdDiagnostics(deviceId: value),
          );
    _appVersionFuture = AppMetadataService.appVersion();
    _accountIdentityFuture = _loadAccountIdentity();
    _apiBaseUrlController = TextEditingController();
    _gatewayApiBaseUrlController = TextEditingController();
    _chatroomWsBaseUrlController = TextEditingController();
    _apiBaseUrlController.addListener(_handleEndpointTextChanged);
    _gatewayApiBaseUrlController.addListener(_handleEndpointTextChanged);
    _chatroomWsBaseUrlController.addListener(_handleEndpointTextChanged);
    _loadEndpointOverrides();
    unawaited(_loadTilemapSettingsButtonVisibility());
    unawaited(AppServicesScope.read(context).gemWallet.refresh());
  }

  @override
  void dispose() {
    _apiBaseUrlController.removeListener(_handleEndpointTextChanged);
    _gatewayApiBaseUrlController.removeListener(_handleEndpointTextChanged);
    _chatroomWsBaseUrlController.removeListener(_handleEndpointTextChanged);
    _apiBaseUrlController.dispose();
    _gatewayApiBaseUrlController.dispose();
    _chatroomWsBaseUrlController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback callback) => setState(callback);

  Future<void> _loadTilemapSettingsButtonVisibility() async {
    final visible = await tilemapSettingsButtonVisibility.load();
    if (!mounted) return;
    _updateState(() {
      _showTilemapSettingsButton = visible;
      _loadingTilemapSettingsButtonVisibility = false;
    });
  }

  Future<void> _setTilemapSettingsButtonVisibility(bool visible) async {
    if (_loadingTilemapSettingsButtonVisibility ||
        _savingTilemapSettingsButtonVisibility) {
      return;
    }
    final previousValue = _showTilemapSettingsButton;
    _updateState(() {
      _showTilemapSettingsButton = visible;
      _savingTilemapSettingsButtonVisibility = true;
    });
    try {
      await tilemapSettingsButtonVisibility.setVisible(visible);
    } catch (error) {
      if (!mounted) return;
      _updateState(() => _showTilemapSettingsButton = previousValue);
      showGenesisToast(context, 'Save failed: $error');
    } finally {
      if (mounted) {
        _updateState(() => _savingTilemapSettingsButtonVisibility = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalContentPadding = widget.dismissBeforePreview ? 0.0 : 20.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return SizedBox(
          height: height,
          child: DefaultTabController(
            length: _developerPageTabs.length,
            child: Column(
              children: [
                SecendTabs(
                  labels: _developerPageTabs,
                  horizontalPadding: horizontalContentPadding,
                  labelPadding: const EdgeInsets.only(right: 16),
                  verticalPadding: 0,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildInfoTab(horizontalContentPadding),
                      _buildTestTab(horizontalContentPadding),
                      const _DeveloperEmptyTab(
                        key: ValueKey<String>('developer-network-tab'),
                        title: 'Network',
                      ),
                      const _DeveloperEmptyTab(
                        key: ValueKey<String>('developer-websocket-tab'),
                        title: 'WebSocket',
                      ),
                      const _DeveloperEmptyTab(
                        key: ValueKey<String>('developer-log-tab'),
                        title: 'Log',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(double horizontalPadding) {
    return ListView(
      key: const PageStorageKey<String>('developer-info-tab-scroll'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        10,
        horizontalPadding,
        20,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        FutureBuilder<_DeveloperAccountIdentity>(
          future: _accountIdentityFuture,
          builder: (context, snapshot) => _buildAccountIdentityRows(snapshot),
        ),
        const SizedBox(height: _itemGap),
        _buildGemBalanceInfoRow(),
        const SizedBox(height: _itemGap),
        FutureBuilder<DeviceIdDiagnostics>(
          future: _deviceIdDiagnosticsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _DeveloperInfoSingleLineRow(
                title: 'Device ID',
                content: 'Loading...',
              );
            }
            return _buildDeviceIdDiagnostics(snapshot.data);
          },
        ),
        const SizedBox(height: _itemGap),
        FutureBuilder<AppVersionInfo>(
          future: _appVersionFuture,
          builder: (context, snapshot) {
            final value = snapshot.connectionState == ConnectionState.done
                ? _versionLabel(snapshot.data)
                : 'Loading...';
            return _DeveloperInfoRow(title: 'Version', content: value);
          },
        ),
        const SizedBox(height: _itemGap),
        const _DeveloperInfoRow(title: 'Build', content: _buildModeLabel),
        const SizedBox(height: _itemGap),
        ValueListenableBuilder<String>(
          valueListenable: genesisCurrentPageClassName,
          builder: (context, pageName, _) {
            return _DeveloperInfoRow(title: 'Current Page', content: pageName);
          },
        ),
        const SizedBox(height: _itemGap),
        ValueListenableBuilder<AgentControlStatus>(
          valueListenable: agentControlStatus,
          builder: (context, status, _) {
            return _DeveloperInfoRow(
              title: 'Agent CLI',
              content: _formatAgentControlStatus(status),
            );
          },
        ),
        const SizedBox(height: 18),
        ..._buildEndpointSection(),
      ],
    );
  }

  List<Widget> _buildEndpointSection() {
    return [
      _DeveloperEndpointHeader(
        isTestEnvironment: _isUsingTestEndpointHost,
        enabled: !_loadingEndpointOverrides && !_savingEndpointOverrides,
        onPressed: () => unawaited(_switchEndpointEnvironment()),
      ),
      const SizedBox(height: 12),
      _DeveloperEndpointField(
        key: const ValueKey<String>('developer-api-base-url-field'),
        label: 'API HTTPS',
        scheme: 'https://',
        hintText: _defaultEndpointHost,
        controller: _apiBaseUrlController,
      ),
      const SizedBox(height: _itemGap),
      _DeveloperEndpointField(
        key: const ValueKey<String>('developer-gateway-api-base-url-field'),
        label: 'Gateway',
        scheme: 'https://',
        hintText: _defaultEndpointHost,
        controller: _gatewayApiBaseUrlController,
      ),
      const SizedBox(height: _itemGap),
      _DeveloperEndpointField(
        key: const ValueKey<String>('developer-chatroom-ws-base-url-field'),
        label: 'Chat WSS',
        scheme: 'wss://',
        hintText: _defaultEndpointHost,
        controller: _chatroomWsBaseUrlController,
      ),
    ];
  }

  Widget _buildTestTab(double horizontalPadding) {
    return ListView(
      key: const PageStorageKey<String>('developer-test-tab-scroll'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        10,
        horizontalPadding,
        20,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _DeveloperToggleRow(
          sectionTitle: 'Tilemap',
          label: 'Show settings button',
          value: _showTilemapSettingsButton,
          enabled:
              !_loadingTilemapSettingsButtonVisibility &&
              !_savingTilemapSettingsButtonVisibility,
          switchKey: const ValueKey<String>(
            'developer-tilemap-settings-button-switch',
          ),
          onChanged: (value) {
            unawaited(_setTilemapSettingsButtonVisibility(value));
          },
        ),
        const SizedBox(height: 18),
        GenesisPrimaryButton(
          label: 'Creating',
          onPressed: _showCreatingWaitOverlayPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Launching',
          onPressed: _showLaunchingWaitOverlayPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Progressing',
          onPressed: _showProgressingWaitOverlayPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Preview Gem purchase sheet',
          onPressed: _showGemPurchaseSheetPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Preview purchase overlay',
          onPressed: _showGemPurchaseOverlayPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Preview Daily Check-in',
          onPressed: _showDailyCheckInPreview,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: _clearingDirectMessageCache
              ? 'Clearing...'
              : 'Clear direct message cache',
          onPressed: _clearingDirectMessageCache
              ? null
              : _clearDirectMessageCache,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: _clearingImageCache ? 'Clearing...' : 'Clear image cache',
          onPressed: _clearingImageCache ? null : _clearImageCache,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: _clearingGatewayAuth ? 'Clearing...' : 'Clear Gateway auth',
          onPressed: _clearingGatewayAuth ? null : _clearGatewayAuth,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: _verifyingGatewaySignature
              ? 'Testing Gateway signature...'
              : 'Test Gateway signature',
          onPressed: _verifyingGatewaySignature
              ? null
              : _verifyGatewaySignature,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
        if (_gatewaySignatureVerifyResult != null) ...[
          const SizedBox(height: _itemGap),
          _DeveloperInfoBlock(
            title: 'Gateway signature response',
            content: _gatewaySignatureVerifyResult!,
          ),
        ],
        const SizedBox(height: _itemGap),
        GenesisPrimaryButton(
          label: 'Hide debug button',
          onPressed: _hideDebugButton,
          backgroundColor: const Color(0xFFE1E1E3),
          foregroundColor: Colors.black,
        ),
      ],
    );
  }
}

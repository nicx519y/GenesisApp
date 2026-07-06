import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/gateway_auth.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';

import '../../app/agent_control/agent_control_status.dart';
import '../../app/config/app_endpoint_overrides.dart';
import '../../app/config/app_config.dart';
import '../../app/debug_floating_button_visibility.dart';
import '../../app/debug_page_tracker.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_generation_wait_overlay.dart';
import '../../components/genesis_logo.dart';
import '../../components/page_header.dart';
import '../../network/genesis_api.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';

const String _buildModeLabel = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

const String _launchPreviewOriginId = 'o_G7DBQM';
const String _launchPreviewWaitTitle = 'Launching the Worldo';
const String _launchPreviewWaitMessage =
    'In world, click the map, enter the location, and start interacting with the characters to move the world forward.';

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: 'Developer page'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: const DeveloperPageContent(),
        ),
      ),
    );
  }
}

class DeveloperPageSheet extends StatelessWidget {
  const DeveloperPageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = GenesisSafeAreaInsets.bottom(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Developer page',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: DeveloperPageContent(
                    dismissBeforePreview: true,
                    onDismissBeforePreview: () async {
                      await Navigator.of(context).maybePop();
                    },
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(height: 24 + bottomPadding),
              ),
            ],
          ),
        ),
      ),
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
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _gatewayApiBaseUrlController;
  late final TextEditingController _chatroomWsBaseUrlController;
  bool _clearingDirectMessageCache = false;
  bool _clearingImageCache = false;
  bool _clearingGatewayAuth = false;
  bool _verifyingGatewaySignature = false;
  bool _loadingEndpointOverrides = true;
  bool _savingEndpointOverrides = false;
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
    _apiBaseUrlController = TextEditingController();
    _gatewayApiBaseUrlController = TextEditingController();
    _chatroomWsBaseUrlController = TextEditingController();
    _apiBaseUrlController.addListener(_handleEndpointTextChanged);
    _gatewayApiBaseUrlController.addListener(_handleEndpointTextChanged);
    _chatroomWsBaseUrlController.addListener(_handleEndpointTextChanged);
    _loadEndpointOverrides();
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

  void _handleEndpointTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadEndpointOverrides() async {
    final overrides = await AppEndpointOverrideStore.load();
    if (!mounted) return;
    _apiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.apiBaseUrl ?? overrides.chatroomHttpBaseUrl,
    );
    _gatewayApiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.gatewayApiBaseUrl,
    );
    _chatroomWsBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.chatroomWsBaseUrl,
    );
    setState(() => _loadingEndpointOverrides = false);
  }

  Future<void> _clearDirectMessageCache() async {
    if (_clearingDirectMessageCache) return;
    setState(() => _clearingDirectMessageCache = true);
    final services = AppServicesScope.read(context);
    try {
      await services.directMessageConversations.clearCache();
      await services.directMessageMessages.clearCache();
      if (!mounted) return;
      showGenesisToast(context, 'Direct message cache cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        setState(() => _clearingDirectMessageCache = false);
      }
    }
  }

  Future<void> _clearImageCache() async {
    if (_clearingImageCache) return;
    setState(() => _clearingImageCache = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
      if (!mounted) return;
      showGenesisToast(context, 'Image cache cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        setState(() => _clearingImageCache = false);
      }
    }
  }

  Future<void> _clearGatewayAuth() async {
    if (_clearingGatewayAuth) return;
    setState(() => _clearingGatewayAuth = true);
    try {
      await clearGatewayAuthLocalState();
      if (!mounted) return;
      final config = AppServicesScope.read(context).config;
      AppServicesScope.replaceWithConfig(context, config);
      showGenesisToast(context, 'Gateway auth cleared');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
    } finally {
      if (mounted) {
        setState(() => _clearingGatewayAuth = false);
      }
    }
  }

  Future<void> _verifyGatewaySignature() async {
    if (_verifyingGatewaySignature) return;
    setState(() {
      _verifyingGatewaySignature = true;
      _gatewaySignatureVerifyResult = 'Testing...';
    });
    try {
      final coordinator = AppServicesScope.read(context).gatewayAuth;
      if (coordinator == null) {
        throw StateError('Gateway auth is unavailable in mock mode.');
      }
      final response = await coordinator.verifyLocalSignature();
      final output = 'HTTP ${response.statusCode}\n${response.prettyBody()}';
      debugPrint('[GatewayAuth][SignatureVerify]\n$output');
      if (!mounted) return;
      setState(() => _gatewaySignatureVerifyResult = output);
      showGenesisToast(context, 'Gateway signature verify completed');
    } catch (error) {
      debugPrint('[GatewayAuth][SignatureVerify] failed: $error');
      if (!mounted) return;
      final output = 'Failed: $error';
      setState(() => _gatewaySignatureVerifyResult = output);
      showGenesisToast(context, output);
    } finally {
      if (mounted) {
        setState(() => _verifyingGatewaySignature = false);
      }
    }
  }

  Future<void> _saveEndpointOverrides({String? successMessage}) async {
    if (_savingEndpointOverrides || _loadingEndpointOverrides) return;
    setState(() => _savingEndpointOverrides = true);
    try {
      final overrides = AppEndpointOverrides(
        apiBaseUrl: AppEndpointOverrideStore.normalizeHttpsApiBaseUrl(
          _apiBaseUrlController.text,
        ),
        gatewayApiBaseUrl:
            AppEndpointOverrideStore.normalizeHttpsGatewayApiBaseUrl(
              _gatewayApiBaseUrlController.text,
            ),
        chatroomHttpBaseUrl: AppEndpointOverrideStore.normalizeHttpsBaseUrl(
          _apiBaseUrlController.text,
        ),
        chatroomWsBaseUrl: AppEndpointOverrideStore.normalizeWssBaseUrl(
          _chatroomWsBaseUrlController.text,
        ),
      );
      await AppEndpointOverrideStore.save(overrides);
      if (!mounted) return;
      final config = overrides.applyTo(const AppConfig());
      AppServicesScope.replaceWithConfig(context, config);
      _apiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
        overrides.apiBaseUrl,
      );
      _gatewayApiBaseUrlController.text =
          AppEndpointOverrideStore.displayDomain(overrides.gatewayApiBaseUrl);
      _chatroomWsBaseUrlController.text =
          AppEndpointOverrideStore.displayDomain(overrides.chatroomWsBaseUrl);
      showGenesisToast(
        context,
        successMessage ?? 'Saved. New requests use endpoints.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showGenesisToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Save failed: $error');
    } finally {
      if (mounted) {
        setState(() => _savingEndpointOverrides = false);
      }
    }
  }

  void _hideDebugButton() {
    hideGenesisDebugFloatingButton();
    Navigator.of(context).maybePop();
  }

  bool get _isUsingTestEndpointHost {
    return _effectiveEndpointHost(_apiBaseUrlController) == _testEndpointHost &&
        _effectiveEndpointHost(_gatewayApiBaseUrlController) ==
            _testEndpointHost &&
        _effectiveEndpointHost(_chatroomWsBaseUrlController) ==
            _testEndpointHost;
  }

  String _effectiveEndpointHost(TextEditingController controller) {
    final value = controller.text.trim().toLowerCase();
    return value.isEmpty ? _defaultEndpointHost : value;
  }

  Future<void> _switchEndpointEnvironment() async {
    if (_loadingEndpointOverrides || _savingEndpointOverrides) return;
    final host = _isUsingTestEndpointHost
        ? _productionEndpointHost
        : _testEndpointHost;
    final successMessage = _isUsingTestEndpointHost ? '已切换到正式环境' : '已切换到测试环境';
    _apiBaseUrlController.text = host;
    _gatewayApiBaseUrlController.text = host;
    _chatroomWsBaseUrlController.text = host;
    await _saveEndpointOverrides(successMessage: successMessage);
  }

  Future<void> _showCreatingWaitOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    if (!navigator.mounted) return;
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GenesisGenerationWaitOverlay(
          title: 'Creating your Worldo',
          illustration: const Center(
            child: GenesisLogo(height: 88, width: 152),
          ),
          perspectiveLines: const [
            'A floating city where every district changes its laws at sunrise, and every resident keeps a private map of the rules they trust.',
            'Magic behaves like public infrastructure. Promises, debts, weather, and streetlights all run through the same civic engine.',
            'Mira: Exiled route-maker. Patient, skeptical, and protective of anyone who admits they are lost.',
            'Jon: Archive courier. Restless, charming, and far too willing to trade secrets for a shortcut.',
          ],
          onBarrierTap: () => Navigator.of(dialogContext).maybePop(),
          onBackPressed: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Future<void> _showLaunchingWaitOverlayPreview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final api = AppServicesScope.read(context).api;
    if (widget.dismissBeforePreview) {
      await widget.onDismissBeforePreview?.call();
    }
    final origin = await () async {
      try {
        return await api.getOrigin(_launchPreviewOriginId);
      } catch (_) {
        return null;
      }
    }();
    if (origin == null) {
      if (navigator.mounted) {
        showGenesisToast(
          navigator.context,
          'Failed to load launch preview origin.',
        );
      }
      return;
    }
    final avatars = origin.characters
        .map((character) {
          return GenesisGenerationWaitAvatar(
            name: character.name.trim(),
            url: character.avatar.trim(),
          );
        })
        .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
        .toList(growable: false);
    if (!navigator.mounted) return;
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GenesisGenerationWaitOverlay(
          title: _launchPreviewWaitTitle,
          message: _launchPreviewWaitMessage,
          characterAvatars: avatars,
          onBarrierTap: () => Navigator.of(dialogContext).maybePop(),
          onBackPressed: () => Navigator.of(dialogContext).maybePop(),
        );
      },
    );
  }

  Widget _buildDeviceIdDiagnostics(DeviceIdDiagnostics? diagnostics) {
    final deviceId = _infoValue(diagnostics?.deviceId);
    if (diagnostics?.hasAndroidBreakdown != true) {
      return _DeveloperInfoRow(title: 'Device ID', content: deviceId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeveloperInfoSingleLineRow(
          title: 'ANDROID_ID',
          content: _infoValue(diagnostics?.androidId),
        ),
        const SizedBox(height: _itemGap),
        _DeveloperInfoSingleLineRow(
          title: 'AAID',
          content: _infoValue(diagnostics?.aaid),
        ),
        const SizedBox(height: _itemGap),
        _DeveloperInfoSingleLineRow(title: 'Device ID', content: deviceId),
      ],
    );
  }

  String _infoValue(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? 'unknown' : trimmed;
  }

  String _versionLabel(AppVersionInfo? versionInfo) {
    final versionName = versionInfo?.versionName.trim() ?? '';
    final versionCode = versionInfo?.versionCode.trim() ?? '';
    final base = AboutUsPage.versionLabel(
      versionName,
    ).replaceFirst(RegExp('^v'), '');
    return versionCode.isEmpty ? base : '$base/$versionCode';
  }

  String _formatAgentControlStatus(AgentControlStatus status) {
    final parts = <String>[status.label];
    final port = status.port;
    if (status.running && port != null) {
      parts.add('${status.host}:$port');
    }
    if (status.enabled) {
      parts.add(
        status.tokenConfigured ? 'token configured' : 'generated token',
      );
      final preview = status.tokenPreview;
      if (preview != null) parts.add(preview);
    }
    final error = status.lastError;
    if (error != null && error.trim().isNotEmpty) {
      parts.add(error);
    }
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          FutureBuilder<DeviceIdDiagnostics>(
            future: _deviceIdDiagnosticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _DeveloperInfoRow(
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
              return _DeveloperInfoRow(
                title: 'Current Page',
                content: pageName,
              );
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
          const SizedBox(height: 18),
          const SizedBox(height: _itemGap),
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
      ),
    );
  }
}

class _DeveloperSectionTitle extends StatelessWidget {
  const _DeveloperSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }
}

class _DeveloperEndpointHeader extends StatelessWidget {
  const _DeveloperEndpointHeader({
    required this.isTestEnvironment,
    required this.enabled,
    required this.onPressed,
  });

  final bool isTestEnvironment;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionText = isTestEnvironment ? '切换到正式环境' : '切换到测试环境';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: _DeveloperSectionTitle('Endpoint overrides')),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                actionText,
                textAlign: TextAlign.right,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.black : const Color(0xFFA8A8AD),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperEndpointField extends StatelessWidget {
  const _DeveloperEndpointField({
    super.key,
    required this.label,
    required this.scheme,
    required this.hintText,
    required this.controller,
  });

  final String label;
  final String scheme;
  final String hintText;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final host = controller.text.trim().isEmpty
        ? hintText
        : controller.text.trim();
    final displayText = '$scheme$host';
    return _DeveloperInfoSingleLineRow(title: label, content: displayText);
  }
}

class _DeveloperInfoSingleLineRow extends StatelessWidget {
  const _DeveloperInfoSingleLineRow({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  static const double _titleWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _titleWidth,
          child: Text(
            '$title:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _copyContent(context),
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                content,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}

class _DeveloperInfoRow extends StatelessWidget {
  const _DeveloperInfoRow({required this.title, required this.content});

  final String title;
  final String content;

  static const double _titleWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _titleWidth,
          child: Text(
            '$title:',
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _copyContent(context),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}

class _DeveloperInfoBlock extends StatelessWidget {
  const _DeveloperInfoBlock({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _copyContent(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title:',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}

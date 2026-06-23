import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';

import '../../app/config/app_endpoint_overrides.dart';
import '../../app/config/app_config.dart';
import '../../app/debug_floating_button_visibility.dart';
import '../../app/debug_page_tracker.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';

const String _buildModeLabel = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: 'Developer page'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      key: const ValueKey<String>('developer-page-sheet-keyboard-padding'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Text(
                    'Developer page',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: DeveloperPageContent(),
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
      ),
    );
  }
}

class DeveloperPageContent extends StatefulWidget {
  const DeveloperPageContent({super.key});

  @override
  State<DeveloperPageContent> createState() => _DeveloperPageContentState();
}

class _DeveloperPageContentState extends State<DeveloperPageContent> {
  static const double _itemGap = 8;

  late final Future<DeviceIdDiagnostics> _deviceIdDiagnosticsFuture;
  late final Future<AppVersionInfo> _appVersionFuture;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _chatroomWsBaseUrlController;
  bool _clearingDirectMessageCache = false;
  bool _clearingImageCache = false;
  bool _loadingEndpointOverrides = true;
  bool _savingEndpointOverrides = false;

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
    _chatroomWsBaseUrlController = TextEditingController();
    _loadEndpointOverrides();
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _chatroomWsBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadEndpointOverrides() async {
    final overrides = await AppEndpointOverrideStore.load();
    if (!mounted) return;
    _apiBaseUrlController.text = AppEndpointOverrideStore.displayDomain(
      overrides.apiBaseUrl ?? overrides.chatroomHttpBaseUrl,
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

  Future<void> _saveEndpointOverrides() async {
    if (_savingEndpointOverrides || _loadingEndpointOverrides) return;
    setState(() => _savingEndpointOverrides = true);
    try {
      final overrides = AppEndpointOverrides(
        apiBaseUrl: AppEndpointOverrideStore.normalizeHttpsApiBaseUrl(
          _apiBaseUrlController.text,
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
      _chatroomWsBaseUrlController.text =
          AppEndpointOverrideStore.displayDomain(overrides.chatroomWsBaseUrl);
      showGenesisToast(
        context,
        'Saved. New requests will use these endpoints.',
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

  Future<void> _clearEndpointOverrides() async {
    if (_savingEndpointOverrides || _loadingEndpointOverrides) return;
    setState(() => _savingEndpointOverrides = true);
    try {
      await AppEndpointOverrideStore.clear();
      if (!mounted) return;
      AppServicesScope.replaceWithConfig(context, const AppConfig());
      _apiBaseUrlController.clear();
      _chatroomWsBaseUrlController.clear();
      showGenesisToast(context, 'Endpoint overrides cleared.');
    } catch (error) {
      if (!mounted) return;
      showGenesisToast(context, 'Clear failed: $error');
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

  Widget _buildDeviceIdDiagnostics(DeviceIdDiagnostics? diagnostics) {
    final deviceId = _infoValue(diagnostics?.deviceId);
    if (diagnostics?.hasAndroidBreakdown != true) {
      return _DeveloperInfoRow(title: 'Device ID', content: deviceId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeveloperInfoBlock(
          title: 'ANDROID_ID',
          content: _infoValue(diagnostics?.androidId),
        ),
        const SizedBox(height: _itemGap),
        _DeveloperInfoBlock(
          title: 'AAID',
          content: _infoValue(diagnostics?.aaid),
        ),
        const SizedBox(height: _itemGap),
        _DeveloperInfoBlock(title: 'Device ID', content: deviceId),
      ],
    );
  }

  String _infoValue(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? 'unknown' : trimmed;
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
                  ? AboutUsPage.versionLabel(snapshot.data?.versionName ?? '')
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
          const SizedBox(height: 18),
          const _DeveloperSectionTitle('Endpoint overrides'),
          const SizedBox(height: 12),
          _DeveloperEndpointField(
            key: const ValueKey<String>('developer-api-base-url-field'),
            label: 'API HTTPS',
            scheme: 'https://',
            hintText: 'dev.hushie.ai',
            controller: _apiBaseUrlController,
            enabled: !_loadingEndpointOverrides && !_savingEndpointOverrides,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _itemGap),
          _DeveloperEndpointField(
            key: const ValueKey<String>('developer-chatroom-ws-base-url-field'),
            label: 'Chat WSS',
            scheme: 'wss://',
            hintText: 'dev.hushie.ai',
            controller: _chatroomWsBaseUrlController,
            enabled: !_loadingEndpointOverrides && !_savingEndpointOverrides,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveEndpointOverrides(),
          ),
          const SizedBox(height: _itemGap),
          GenesisPrimaryButton(
            label: _savingEndpointOverrides ? 'Saving...' : 'Save endpoints',
            onPressed: _savingEndpointOverrides || _loadingEndpointOverrides
                ? null
                : _saveEndpointOverrides,
            backgroundColor: const Color(0xFFE1E1E3),
            foregroundColor: Colors.black,
          ),
          const SizedBox(height: _itemGap),
          GenesisPrimaryButton(
            label: 'Clear endpoint overrides',
            onPressed: _savingEndpointOverrides || _loadingEndpointOverrides
                ? null
                : _clearEndpointOverrides,
            backgroundColor: const Color(0xFFE1E1E3),
            foregroundColor: Colors.black,
          ),
          const SizedBox(height: 18),
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

class _DeveloperEndpointField extends StatelessWidget {
  const _DeveloperEndpointField({
    super.key,
    required this.label,
    required this.scheme,
    required this.hintText,
    required this.controller,
    required this.enabled,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String scheme;
  final String hintText;
  final TextEditingController controller;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Text(
                scheme,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.url,
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  scrollPadding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 120,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: const TextStyle(
                      color: Color(0xFFA8A8AD),
                      fontSize: 13,
                      letterSpacing: 0,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../app/bootstrap/app_services_scope.dart';
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
    return const Scaffold(
      appBar: GenesisBackAppBar(pageName: 'Developer page'),
      body: SafeArea(child: DeveloperPageContent()),
    );
  }
}

class DeveloperPageSheet extends StatelessWidget {
  const DeveloperPageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
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
                child: SingleChildScrollView(child: DeveloperPageContent()),
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
  const DeveloperPageContent({super.key});

  @override
  State<DeveloperPageContent> createState() => _DeveloperPageContentState();
}

class _DeveloperPageContentState extends State<DeveloperPageContent> {
  static const double _itemGap = 8;

  late final Future<String> _deviceIdFuture;
  late final Future<AppVersionInfo> _appVersionFuture;
  bool _clearingDirectMessageCache = false;

  @override
  void initState() {
    super.initState();
    _deviceIdFuture = AppServicesScope.read(context).deviceId.getDeviceId();
    _appVersionFuture = AppMetadataService.appVersion();
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

  void _hideDebugButton() {
    hideGenesisDebugFloatingButton();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          FutureBuilder<String>(
            future: _deviceIdFuture,
            builder: (context, snapshot) {
              final value = snapshot.connectionState == ConnectionState.done
                  ? (snapshot.data?.trim().isNotEmpty == true
                        ? snapshot.data!.trim()
                        : 'unknown')
                  : 'Loading...';
              return _DeveloperInfoRow(title: 'Device ID', content: value);
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

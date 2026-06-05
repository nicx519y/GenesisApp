import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  late final Future<String> _deviceIdFuture;
  bool _clearingDirectMessageCache = false;

  @override
  void initState() {
    super.initState();
    _deviceIdFuture = AppServicesScope.read(context).deviceId.getDeviceId();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'Developer page'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Text(
                'Device ID',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: _deviceIdFuture,
                builder: (context, snapshot) {
                  final value = snapshot.connectionState == ConnectionState.done
                      ? (snapshot.data?.trim().isNotEmpty == true
                            ? snapshot.data!.trim()
                            : 'unknown')
                      : 'Loading...';
                  return SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w400,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}

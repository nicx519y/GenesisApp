import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/debug_floating_button_visibility.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_content_submission_dialog.dart';
import '../../components/page_header.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const int _debugButtonUnlockTapCount = 10;

  int _blankTapCount = 0;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showGenesisActionBox<bool>(
      context: context,
      title: 'Log out of your account?',
      actions: const [
        GenesisActionBoxAction<bool>(label: 'Log out', value: true),
      ],
    );
    if (confirmed == true && context.mounted) {
      await _logout(context);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showGenesisActionBox<bool>(
      context: context,
      title: 'Delete your account?',
      actions: const [
        GenesisActionBoxAction<bool>(label: 'Delete account', value: true),
      ],
    );
    if (confirmed == true && context.mounted) {
      await _deleteAccount(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final services = AppServicesScope.read(context);
    await services.backendAuth.signOut();
    services.notifySessionChanged();
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final services = AppServicesScope.read(context);
    await services.backendAuth.deleteAccount();
    services.notifySessionChanged();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.origin, (route) => false);
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final api = AppServicesScope.read(context).api;
    await showGenesisContentSubmissionDialog(
      context: context,
      title: 'Feedback',
      contentInputKey: const ValueKey<String>('genesis-feedback-content-input'),
      successMessage: 'Feedback submitted',
      failureMessage: 'Feedback failed',
      onSubmit: (content) => api.v1.feedback.create(content: content),
    );
  }

  void _handleBlankTap() {
    final nextCount = _blankTapCount + 1;
    if (nextCount < _debugButtonUnlockTapCount) {
      _blankTapCount = nextCount;
      return;
    }
    _blankTapCount = 0;
    showGenesisDebugFloatingButton();
    showGenesisToast(context, 'Debug button shown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GenesisBackAppBar(
        pageName: 'Settings',
        onBack: () => Navigator.of(context).maybePop(false),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 18),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutUsPage()),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'About us',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFFB5B5B5),
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7E7E7)),
              InkWell(
                onTap: () => _showFeedbackDialog(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFFB5B5B5),
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7E7E7)),
              InkWell(
                onTap: () => _confirmDeleteAccount(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Delete account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFFB5B5B5),
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7E7E7)),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey<String>('settings-debug-button-restore'),
                  behavior: HitTestBehavior.translucent,
                  onTap: _handleBlankTap,
                ),
              ),
              GenesisPrimaryButton(
                label: 'Log out',
                onPressed: () => _confirmLogout(context),
                backgroundColor: const Color(0xFFE1E1E3),
                foregroundColor: Colors.black,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

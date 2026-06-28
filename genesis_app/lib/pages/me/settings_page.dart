import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/debug_floating_button_visibility.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_content_submission_dialog.dart';
import '../../components/login_provider_button.dart';
import '../../components/page_header.dart';
import '../../platform/auth/auth_session.dart';
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
  static const double _logoutButtonWidthFactor = 0.7;
  static final Uri _discordUri = Uri.parse('https://discord.gg/wuKHk7cyX7');

  int _debugUnlockTapCount = 0;

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

  Future<void> _openAccountPage(BuildContext context) async {
    final loggedOut = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const AccountPage()));
    if (loggedOut == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final services = AppServicesScope.read(context);
    await services.backendAuth.signOut();
    services.notifySessionChanged();
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
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

  Future<void> _openDiscord() async {
    try {
      final launched = await launchUrl(
        _discordUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showGenesisToast(context, 'Could not open Discord');
      }
    } catch (_) {
      if (mounted) {
        showGenesisToast(context, 'Could not open Discord');
      }
    }
  }

  void _handleDebugUnlockTap() {
    final nextCount = _debugUnlockTapCount + 1;
    if (nextCount < _debugButtonUnlockTapCount) {
      _debugUnlockTapCount = nextCount;
      return;
    }
    _debugUnlockTapCount = 0;
    showGenesisDebugFloatingButton();
    showGenesisToast(context, 'Debug button shown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: GenesisBackAppBar(
        pageName: 'Settings',
        onBack: () => Navigator.of(context).maybePop(false),
        titleKey: const ValueKey<String>('settings-debug-title-unlock-area'),
        onTitleTap: _handleDebugUnlockTap,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 18),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openAccountPage(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Account',
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openDiscord,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Join Discord',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/custom-icons/svg/discord-svgrepo-com.svg',
                            width: 28,
                            height: 28,
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFB5B5B5),
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7E7E7)),
              const Expanded(child: SizedBox.shrink()),
              GenesisPrimaryButton(
                label: 'Log out',
                width:
                    MediaQuery.sizeOf(context).width * _logoutButtonWidthFactor,
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

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const double _deleteButtonWidthFactor = 0.7;

  IdentityProvider _provider = IdentityProvider.google;
  bool _hasReadAgreement = false;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final userInfo = await AppServicesScope.read(
      context,
    ).sessionStore.readUserInfo();
    if (!mounted) return;
    final rawProvider = (userInfo?['login_provider'] ?? userInfo?['provider'])
        ?.toString()
        .trim()
        .toLowerCase();
    setState(() {
      _provider = rawProvider == IdentityProvider.apple.name
          ? IdentityProvider.apple
          : IdentityProvider.google;
    });
  }

  Future<void> _handleDeletePressed() async {
    if (!_hasReadAgreement) {
      showGenesisToast(context, 'Agree to our terms to continue.');
      return;
    }

    final confirmed = await showGenesisActionBox<bool>(
      context: context,
      title: 'Delete your account?',
      actions: const [
        GenesisActionBoxAction<bool>(label: 'Delete', value: true),
      ],
    );
    if (confirmed == true && mounted) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final services = AppServicesScope.read(context);
    await services.backendAuth.deleteAccount();
    services.notifySessionChanged();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.origin, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'Account'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _CurrentLoginAccountCard(provider: _provider),
                  const SizedBox(height: 42),
                  const Text(
                    'Account Deletion Agreement',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'To ensure the security of your account, please read about '
                    'the consequences of account deletion.\n\n'
                    'Account deletion is not the same as logging out, and once '
                    'canceled, it cannot be undone. Your private data, including '
                    'created characters, search history, chat logs with any '
                    'characters, your favorites, your memories, interaction '
                    'data, and order records, will be irreversibly deleted and '
                    'cannot be recovered upon account deletion.',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _hasReadAgreement = !_hasReadAgreement),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              value: _hasReadAgreement,
                              activeColor: const Color(0xFFFF4D4F),
                              checkColor: Colors.white,
                              onChanged: (value) => setState(
                                () => _hasReadAgreement = value ?? false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I have read the Account Deletion Agreement',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GenesisPrimaryButton(
                    label: 'Delete',
                    width:
                        MediaQuery.sizeOf(context).width *
                        _deleteButtonWidthFactor,
                    onPressed: _handleDeletePressed,
                    backgroundColor: const Color(0xFFE1E1E3),
                    foregroundColor: _hasReadAgreement
                        ? Colors.black
                        : const Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentLoginAccountCard extends StatelessWidget {
  const _CurrentLoginAccountCard({required this.provider});

  final IdentityProvider provider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        child: Column(
          children: [
            const Text(
              'Current login account:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF777777),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            LoginProviderIcon(provider: provider),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';
import 'developer_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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

  Future<void> _logout(BuildContext context) async {
    final services = AppServicesScope.read(context);
    await services.backendAuth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppServicesScope(
                      services: AppServicesScope.read(context),
                      child: const DeveloperPage(),
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Developer page',
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
              const Spacer(),
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

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import 'about_us_page.dart';
import 'chatroom_test_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AppServicesScope.read(context).backendAuth.signOut();
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
                onTap: () => Navigator.of(context).pushNamed(
                  RouteNames.locationChat,
                  arguments: const {
                    'world_id': 'world-1',
                    'world_name': 'World 1',
                    'location_id': 'castle',
                    'location_name': 'Castle',
                  },
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Location chat test',
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
                    builder: (_) => const ChatroomTestPage(),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'WebSocket test',
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
                onPressed: () => _logout(context),
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

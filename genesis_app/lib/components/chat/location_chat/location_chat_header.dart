import 'package:flutter/material.dart';

class LocationChatHeader extends StatelessWidget {
  const LocationChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      height: topInset + 50,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      color: const Color(0xFFF2EFF2).withValues(alpha: 0.96),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 17),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFF526A9F),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected
                            ? Icons.groups_2
                            : connecting
                            ? Icons.sync
                            : Icons.cloud_off,
                        size: 17,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_horiz, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}

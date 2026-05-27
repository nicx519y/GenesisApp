import 'package:flutter/material.dart';

class WorldTopOverlayBar extends StatelessWidget {
  const WorldTopOverlayBar({
    super.key,
    required this.pointsCount,
    required this.controller,
    this.onBack,
  });

  final int pointsCount;
  final TabController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            iconSize: 18,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: controller,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFFFF4D58), width: 1.5),
                insets: EdgeInsets.symmetric(horizontal: 28),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black.withValues(alpha: 0.7),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Map'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Location ($pointsCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

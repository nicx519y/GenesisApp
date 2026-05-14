import 'package:flutter/material.dart';

class MessageCategoryListPage extends StatelessWidget {
  const MessageCategoryListPage({
    super.key,
    required this.title,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                emptyText,
                style: const TextStyle(
                  color: Color(0xFF94979E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final text = items[index];
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

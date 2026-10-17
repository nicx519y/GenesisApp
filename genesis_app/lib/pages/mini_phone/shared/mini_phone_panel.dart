import 'package:flutter/material.dart';
import 'mini_phone_ui.dart';

Widget miniPhonePanel(
  Widget header,
  Widget body, {
  String? subtitle,
  Widget? footer,
}) => SafeArea(
  child: Column(
    children: [
      header,
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            miniPageInset,
            0,
            miniPageInset,
            12,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: miniStyle(12, FontWeight.w400, miniSecondary),
            ),
          ),
        ),
      Expanded(child: body),
      if (footer != null) footer,
    ],
  ),
);

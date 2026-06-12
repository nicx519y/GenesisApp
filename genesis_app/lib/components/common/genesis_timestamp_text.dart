import 'package:flutter/material.dart';

import '../../utils/genesis_timestamp_formatter.dart';

class GenesisTimestampText extends StatelessWidget {
  const GenesisTimestampText({
    super.key,
    required this.timestamp,
    this.fallback = '',
    this.now,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final Object? timestamp;
  final String fallback;
  final DateTime? now;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatGenesisTimestamp(timestamp, fallback: fallback, now: now),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}

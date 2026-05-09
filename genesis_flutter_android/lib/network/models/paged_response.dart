import 'package:flutter/foundation.dart';

@immutable
class PagedResponse<T> {
  const PagedResponse({
    required this.data,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<T> data;
  final int total;
  final int limit;
  final int offset;
}


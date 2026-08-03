import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../app/bootstrap/app_services_scope.dart';

const int compactLocationIdLength = 32;

final RegExp compactLocationIdPattern = RegExp(r'^[0-9a-f]{32}$');

abstract interface class LocationIdGenerator {
  String generate();
}

class UuidLocationIdGenerator implements LocationIdGenerator {
  const UuidLocationIdGenerator();

  @override
  String generate() => const Uuid().v4().replaceAll('-', '');
}

String createUidTimestampHashId({
  required String uid,
  DateTime? timestamp,
  String prefix = '',
}) {
  final normalizedUid = uid.trim().isEmpty ? 'anonymous' : uid.trim();
  final micros = (timestamp ?? DateTime.now().toUtc()).microsecondsSinceEpoch;
  final digest = sha256.convert(utf8.encode('$normalizedUid:$micros'));
  final id = digest.toString().substring(0, 24);
  return prefix.trim().isEmpty ? id : '${prefix.trim()}_$id';
}

Future<String> readCreateOriginUid(BuildContext context) async {
  final uid = (await AppServicesScope.read(
    context,
  ).sessionStore.readUid())?.trim();
  if (uid == null || uid.isEmpty) return 'anonymous';
  return uid;
}

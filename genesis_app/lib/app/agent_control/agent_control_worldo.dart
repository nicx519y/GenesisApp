part of 'agent_control_registry.dart';

const int _worldoBridgeProtocolVersion = 1;

Future<Map<String, Object?>> _worldoCapabilities(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final appVersion = await AppMetadataService.appVersion();
  return {
    'protocolVersion': _worldoBridgeProtocolVersion,
    'platform': defaultTargetPlatform.name,
    'buildMode': _buildModeLabel,
    'apiEnvironment': context.services.config.effectiveApiEnvironment,
    'apiBaseUrl': context.services.config.apiBaseUrl,
    'packageName': appVersion.packageName,
    'versionName': appVersion.versionName,
    'versionCode': appVersion.versionCode,
    'methods': const <String>[
      'auth.profile',
      'worldo.list',
      'worldo.for_edit',
      'worldo.info',
      'worldo.create',
      'worldo.update',
      'POST /worldo/assets',
    ],
    'assetUpload': const <String, Object?>{
      'contentTypes': <String>['image/png', 'image/jpeg', 'image/webp'],
      'maxBytes': 25 * 1024 * 1024,
    },
  };
}

Future<Map<String, Object?>> _authProfile(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final uid = (await context.services.sessionStore.readUid())?.trim() ?? '';
  final token = await context.services.sessionStore.readAuthToken();
  final info = await context.services.sessionStore.readUserInfo();
  return {
    'uid': uid,
    'name': _profileString(info, const [
      'name',
      'user_name',
      'username',
      'display_name',
      'nickname',
    ]),
    'avatar': _profileString(info, const [
      'avatar_url',
      'avatar',
      'profile_image',
    ]),
    'hasUid': uid.isNotEmpty,
    'hasAuthToken': token?.trim().isNotEmpty == true,
    'loggedIn': uid.isNotEmpty && token?.trim().isNotEmpty == true,
  };
}

Future<Map<String, Object?>> _worldoList(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  await _requireWorldoAuth(context);
  final pn = _boundedPositiveInt(
    request.params['pn'],
    fallback: 1,
    max: 100000,
  );
  final rn = _boundedPositiveInt(request.params['rn'], fallback: 20, max: 100);
  final response = await context.services.api.v1.origin.list(
    scene: 'mine',
    pn: pn,
    rn: rn,
  );
  return Map<String, Object?>.from(response);
}

Future<Map<String, Object?>> _worldoForEdit(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  await _requireWorldoAuth(context);
  final originId = _requiredString(request.params, const [
    'origin_id',
    'originId',
    'oid',
  ]);
  final response = await context.services.api.v2.origin.forEdit(
    originId: originId,
  );
  return Map<String, Object?>.from(response);
}

Future<Map<String, Object?>> _worldoInfo(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  await _requireWorldoAuth(context);
  final originId = _requiredString(request.params, const [
    'origin_id',
    'originId',
    'oid',
  ]);
  final response = await context.services.api.v1.origin.info(
    originId: originId,
  );
  return Map<String, Object?>.from(response);
}

Future<Map<String, Object?>> _worldoCreate(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  await _requireWorldoAuth(context);
  final payload = _requiredWorldoPayload(request.params);
  if (request.dryRun) {
    return {'dryRun': true, 'accepted': true};
  }
  final result = await context.services.api.createOriginV2(payload: payload);
  final originId = result.oid.trim();
  if (originId.isEmpty) {
    throw const AgentControlException(
      code: 'invalid_response',
      message: 'origin_id is missing from create response.',
    );
  }
  return {'origin_id': originId, 'status': 20};
}

Future<Map<String, Object?>> _worldoUpdate(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  await _requireWorldoAuth(context);
  final originId = _requiredString(request.params, const [
    'origin_id',
    'originId',
    'oid',
  ]);
  final payload = _requiredWorldoPayload(request.params);
  if (request.dryRun) {
    return {'dryRun': true, 'accepted': true, 'origin_id': originId};
  }
  final result = await context.services.api.updateOriginV2(
    oid: originId,
    payload: payload,
  );
  final updatedOriginId = result.oid.trim();
  if (updatedOriginId.isEmpty) {
    throw const AgentControlException(
      code: 'invalid_response',
      message: 'origin_id is missing from update response.',
    );
  }
  return {'origin_id': updatedOriginId, 'status': 20};
}

Future<void> _requireWorldoAuth(AgentControlContext context) async {
  final uid = await context.services.sessionStore.readUid();
  final token = await context.services.sessionStore.readAuthToken();
  if (uid?.trim().isNotEmpty == true && token?.trim().isNotEmpty == true) {
    return;
  }
  throw const AgentControlException(
    code: 'login_required',
    message:
        'Log in on the connected phone before using remote Worldo features.',
  );
}

Map<String, dynamic> _requiredWorldoPayload(Map<String, Object?> params) {
  final raw = params['payload'];
  if (raw is! Map) {
    throw const AgentControlException(
      code: 'missing_param',
      message: 'payload is required.',
    );
  }
  return Map<String, dynamic>.from(raw);
}

int _boundedPositiveInt(
  Object? raw, {
  required int fallback,
  required int max,
}) {
  final parsed = _intParam(raw);
  if (parsed <= 0) return fallback;
  return parsed > max ? max : parsed;
}

String _profileString(Map<String, dynamic>? info, List<String> keys) {
  if (info == null) return '';
  for (final key in keys) {
    final value = info[key];
    if (value is Map) {
      final nested = asJsonMap(value);
      final url = asString(
        nested['url'],
        fallback: asString(nested['image_url']),
      ).trim();
      if (url.isNotEmpty) return url;
    }
    final text = asString(value).trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

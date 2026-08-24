import '../json_utils.dart';

/// The switch-model button only ever receives `selected_model_code` (e.g.
/// `sedna`); the human title lives on the model catalog, which is a different
/// endpoint. Both are cached side by side in the user-info blob so the button
/// can render a title without pulling the catalog on every room open.
const String kSelectedModelCodeUserInfoKey = 'selected_model_code';
const String kSelectedModelTitlesUserInfoKey = 'selected_model_titles';

Map<String, String> gemModelTitlesFromUserInfo(Map<String, dynamic> userInfo) {
  final raw = userInfo[kSelectedModelTitlesUserInfoKey];
  if (raw is! Map) return const <String, String>{};
  final titles = <String, String>{};
  for (final entry in raw.entries) {
    final code = asString(entry.key).trim();
    final title = asString(entry.value).trim();
    if (code.isEmpty || title.isEmpty) continue;
    titles[code] = title;
  }
  return titles;
}

/// Merges a fresh code/title pair into the cached user info without dropping
/// titles learned earlier. Keyed by code so a server-side model change simply
/// misses the cache instead of showing the previous model's title.
Map<String, dynamic> userInfoWithSelectedGemModel(
  Map<String, dynamic>? currentUserInfo, {
  String selectedModelCode = '',
  Map<String, String> titlesByCode = const <String, String>{},
}) {
  final current = currentUserInfo ?? const <String, dynamic>{};
  final merged = <String, String>{
    ...gemModelTitlesFromUserInfo(current),
    ...titlesByCode,
  }..removeWhere((code, title) => code.isEmpty || title.isEmpty);
  final code = selectedModelCode.trim();
  return <String, dynamic>{
    ...current,
    if (code.isNotEmpty) kSelectedModelCodeUserInfoKey: code,
    if (merged.isNotEmpty) kSelectedModelTitlesUserInfoKey: merged,
  };
}

class GemModelCatalog {
  const GemModelCatalog({
    required this.selectedModelCode,
    required this.groups,
  });

  factory GemModelCatalog.fromJson(Map<String, dynamic> json) {
    final groups = json['list'] is List
        ? (json['list'] as List)
              .whereType<Map>()
              .map((item) => GemModelGroup.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemModelGroup>[];
    return GemModelCatalog(
      selectedModelCode: asString(json['selected_model_code']),
      groups: groups,
    );
  }

  final String selectedModelCode;
  final List<GemModelGroup> groups;

  Map<String, String> titlesByCode() {
    final titles = <String, String>{};
    for (final group in groups) {
      for (final model in group.models) {
        final code = model.modelCode.trim();
        final title = model.title.trim();
        if (code.isEmpty || title.isEmpty) continue;
        titles[code] = title;
      }
    }
    return titles;
  }

  GemModelCatalog copyWith({String? selectedModelCode}) {
    return GemModelCatalog(
      selectedModelCode: selectedModelCode ?? this.selectedModelCode,
      groups: groups,
    );
  }
}

class GemModelGroup {
  const GemModelGroup({
    required this.groupCode,
    required this.groupTitle,
    required this.models,
  });

  factory GemModelGroup.fromJson(Map<String, dynamic> json) {
    final models = json['models'] is List
        ? (json['models'] as List)
              .whereType<Map>()
              .map((item) => GemModel.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemModel>[];
    return GemModelGroup(
      groupCode: asString(json['group_code']),
      groupTitle: asString(json['group_title']),
      models: models,
    );
  }

  final String groupCode;
  final String groupTitle;
  final List<GemModel> models;
}

class GemModel {
  const GemModel({
    required this.modelCode,
    required this.title,
    required this.tags,
    required this.estimatedNextMessageGems,
    required this.estimatedNextTickGems,
    required this.description,
    required this.rangeText,
  });

  factory GemModel.fromJson(Map<String, dynamic> json) {
    final tags = json['tag'] is List
        ? (json['tag'] as List)
              .map((tag) => asString(tag).trim())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return GemModel(
      modelCode: asString(json['model_code']),
      title: asString(json['title']),
      tags: tags,
      estimatedNextMessageGems: asInt(json['estimated_next_message_gems']),
      estimatedNextTickGems: asInt(json['estimated_next_tick_gems']),
      description: asString(json['description']),
      rangeText: asString(json['range_text']),
    );
  }

  final String modelCode;
  final String title;
  final List<String> tags;
  final int estimatedNextMessageGems;
  final int estimatedNextTickGems;
  final String description;
  final String rangeText;
}

class GemModelSelection {
  const GemModelSelection({required this.selectedModelCode});

  factory GemModelSelection.fromJson(Map<String, dynamic> json) {
    return GemModelSelection(
      selectedModelCode: asString(json['selected_model_code']),
    );
  }

  final String selectedModelCode;
}

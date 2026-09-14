import '../json_utils.dart';
import '../../utils/gem_amount.dart';

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
    required this.estimatedNextMessageGemsCent,
    required this.estimatedNextTickGemsCent,
    required this.description,
    required this.minGemsCent,
    required this.maxGemsCent,
    required this.minMemoryTokens,
    required this.maxMemoryTokens,
  });

  factory GemModel.fromJson(Map<String, dynamic> json) {
    final tags = json['tag'] is List
        ? (json['tag'] as List)
              .map((tag) => asString(tag).trim())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final model = GemModel(
      modelCode: asString(json['model_code']),
      title: asString(json['title']),
      tags: tags,
      estimatedNextMessageGemsCent: requireGemCent(
        json['estimated_next_message_gems_cent'],
        fieldName: 'estimated_next_message_gems_cent',
      ),
      estimatedNextTickGemsCent: requireGemCent(
        json['estimated_next_tick_gems_cent'],
        fieldName: 'estimated_next_tick_gems_cent',
      ),
      description: asString(json['description']),
      minGemsCent: _requireRangeInteger(json, 'min_gems_cent'),
      maxGemsCent: _requireRangeInteger(json, 'max_gems_cent'),
      minMemoryTokens: _requireRangeInteger(json, 'min_memory_tokens'),
      maxMemoryTokens: _requireRangeInteger(json, 'max_memory_tokens'),
    );
    if (model.minGemsCent < 0 ||
        model.maxGemsCent < model.minGemsCent ||
        model.minGemsCent != model.estimatedNextMessageGemsCent ||
        model.minMemoryTokens <= 0 ||
        model.maxMemoryTokens < model.minMemoryTokens) {
      throw const FormatException('Invalid model quotation range');
    }
    return model;
  }

  final String modelCode;
  final String title;
  final List<String> tags;
  final int estimatedNextMessageGemsCent;
  final int estimatedNextTickGemsCent;
  final String description;
  final int minGemsCent;
  final int maxGemsCent;

  /// Saved user budget, NOT the current World's used memory.
  final int minMemoryTokens;

  /// System budget ceiling, NOT the budget used for maxGemsCent.
  final int maxMemoryTokens;
}

int _requireRangeInteger(Map<String, dynamic> json, String fieldName) {
  final value = json[fieldName];
  if (value is int) return value;
  throw FormatException('$fieldName must be an integer');
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

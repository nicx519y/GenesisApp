import '../json_utils.dart';

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

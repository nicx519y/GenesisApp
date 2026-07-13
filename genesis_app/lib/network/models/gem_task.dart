import '../json_utils.dart';

class GemTaskList {
  const GemTaskList({required this.groups});

  factory GemTaskList.fromJson(Map<String, dynamic> json) {
    final groups = json['list'] is List
        ? (json['list'] as List)
              .whereType<Map>()
              .map((item) => GemTaskGroup.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemTaskGroup>[];
    return GemTaskList(groups: groups);
  }

  final List<GemTaskGroup> groups;
}

class GemTaskGroup {
  const GemTaskGroup({
    required this.groupCode,
    required this.groupTitle,
    required this.tasks,
  });

  factory GemTaskGroup.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] is List
        ? (json['tasks'] as List)
              .whereType<Map>()
              .map((item) => GemTask.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemTask>[];
    return GemTaskGroup(
      groupCode: asString(json['group_code']),
      groupTitle: asString(json['group_title']),
      tasks: tasks,
    );
  }

  final String groupCode;
  final String groupTitle;
  final List<GemTask> tasks;
}

class GemTask {
  const GemTask({
    required this.taskCode,
    required this.title,
    required this.description,
    required this.rewardGems,
    required this.rewardValidDays,
    required this.cycleType,
    required this.cycleKey,
    required this.progress,
    required this.targetCount,
    required this.progressText,
    required this.status,
    required this.actionText,
  });

  factory GemTask.fromJson(Map<String, dynamic> json) {
    return GemTask(
      taskCode: asString(json['task_code']),
      title: asString(json['title']),
      description: asString(json['description']),
      rewardGems: asInt(json['reward_gems']),
      rewardValidDays: asInt(json['reward_valid_days']),
      cycleType: asString(json['cycle_type']),
      cycleKey: asString(json['cycle_key']),
      progress: asInt(json['progress']),
      targetCount: asInt(json['target_count']),
      progressText: asString(json['progress_text']),
      status: asString(json['status'], fallback: 'in_progress'),
      actionText: asString(json['action_text']),
    );
  }

  final String taskCode;
  final String title;
  final String description;
  final int rewardGems;
  final int rewardValidDays;
  final String cycleType;
  final String cycleKey;
  final int progress;
  final int targetCount;
  final String progressText;
  final String status;
  final String actionText;

  bool get isInProgress => status == 'in_progress';
  bool get isClaimed => status == 'claimed';
  bool get isClaimable => status == 'claimable';
}

import '../json_utils.dart';

class GemHome {
  const GemHome({
    required this.balance,
    required this.products,
    required this.taskGroups,
  });

  factory GemHome.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] is Map ? asJsonMap(json['wallet']) : {};
    final products = json['products'] is List
        ? (json['products'] as List)
              .whereType<Map>()
              .map((item) => GemProduct.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemProduct>[];
    final taskGroups = json['task_groups'] is List
        ? (json['task_groups'] as List)
              .whereType<Map>()
              .map((item) => GemTaskGroup.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemTaskGroup>[];

    return GemHome(
      balance: asInt(wallet['balance']),
      products: products,
      taskGroups: taskGroups,
    );
  }

  final int balance;
  final List<GemProduct> products;
  final List<GemTaskGroup> taskGroups;
}

class GemProduct {
  const GemProduct({
    required this.productId,
    required this.appleProductId,
    required this.googleProductId,
    required this.baseGems,
    required this.bonusGems,
    required this.priceCurrencyCode,
    required this.priceAmount,
    required this.canPurchase,
    required this.activityType,
  });

  factory GemProduct.fromJson(Map<String, dynamic> json) {
    return GemProduct(
      productId: asString(json['product_id']),
      appleProductId: asString(json['apple_product_id']),
      googleProductId: asString(json['google_product_id']),
      baseGems: asInt(json['base_gems']),
      bonusGems: asInt(json['bonus_gems']),
      priceCurrencyCode: asString(
        json['price_currency_code'],
        fallback: 'USD',
      ).toUpperCase(),
      priceAmount: asInt(json['price_amount']),
      canPurchase: asBool(json['can_purchase'], fallback: true),
      activityType: asString(json['activity_type'], fallback: 'none'),
    );
  }

  final String productId;
  final String appleProductId;
  final String googleProductId;
  final int baseGems;
  final int bonusGems;
  final String priceCurrencyCode;
  final int priceAmount;
  final bool canPurchase;
  final String activityType;

  int get totalGems => baseGems + bonusGems;

  String get tagText {
    if (activityType == 'first_purchase_bonus') return 'First top-up';
    if (bonusGems > 0) return 'Bonus';
    return '';
  }
}

class GemTaskGroup {
  const GemTaskGroup({
    required this.groupCode,
    required this.groupTitle,
    required this.displayOrder,
    required this.tasks,
  });

  factory GemTaskGroup.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] is List
        ? (json['tasks'] as List)
              .whereType<Map>()
              .map((item) => GemTask.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemTask>[];
    final sortedTasks = [...tasks]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return GemTaskGroup(
      groupCode: asString(json['group_code']),
      groupTitle: asString(json['group_title']),
      displayOrder: asInt(json['display_order']),
      tasks: sortedTasks,
    );
  }

  final String groupCode;
  final String groupTitle;
  final int displayOrder;
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
    required this.progress,
    required this.targetCount,
    required this.progressText,
    required this.status,
    required this.actionType,
    required this.actionText,
    required this.actionTarget,
    required this.displayOrder,
  });

  factory GemTask.fromJson(Map<String, dynamic> json) {
    return GemTask(
      taskCode: asString(json['task_code']),
      title: asString(json['title']),
      description: asString(json['description']),
      rewardGems: asInt(json['reward_gems']),
      rewardValidDays: asInt(json['reward_valid_days']),
      cycleType: asString(json['cycle_type']),
      progress: asInt(json['progress']),
      targetCount: asInt(json['target_count']),
      progressText: asString(json['progress_text']),
      status: asString(json['status'], fallback: 'in_progress'),
      actionType: asString(json['action_type']),
      actionText: asString(json['action_text'], fallback: 'Go'),
      actionTarget: asString(json['action_target']),
      displayOrder: asInt(json['display_order']),
    );
  }

  final String taskCode;
  final String title;
  final String description;
  final int rewardGems;
  final int rewardValidDays;
  final String cycleType;
  final int progress;
  final int targetCount;
  final String progressText;
  final String status;
  final String actionType;
  final String actionText;
  final String actionTarget;
  final int displayOrder;

  bool get isClaimed => status == 'claimed';
  bool get isClaimable => status == 'claimable';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_records.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';

void main() {
  test('Gem models parse integer cent fields', () {
    expect(
      GemWallet.fromJson(<String, dynamic>{
        'wallet': <String, dynamic>{'balance_cent': 12345},
      }).balanceCent,
      12345,
    );
    expect(
      GemProduct.fromJson(<String, dynamic>{
        'base_gems_cent': 50000,
        'bonus_gems_cent': 5000,
      }).totalGemsCent,
      55000,
    );
    expect(
      GemRecordItem.fromJson(<String, dynamic>{'amount_cent': -400}).amountCent,
      -400,
    );
    expect(
      GemTask.fromJson(<String, dynamic>{
        'reward_gems_cent': 2000,
      }).rewardGemsCent,
      2000,
    );
    final model = GemModel.fromJson(<String, dynamic>{
      'estimated_next_message_gems_cent': 400,
      'estimated_next_tick_gems_cent': 300,
    });
    expect(model.estimatedNextMessageGemsCent, 400);
    expect(model.estimatedNextTickGemsCent, 300);
    expect(
      ChatroomBalanceLow.fromEnvelope(
        const ChatroomEnvelope(
          type: 'balance_low',
          payload: <String, dynamic>{'balance_cent': 1000},
        ),
      ).balanceCent,
      1000,
    );
  });

  test('Gem models reject missing and non-integer cent fields', () {
    for (final invalid in <Object?>[null, 100.0, '100']) {
      expect(
        () => GemWallet.fromJson(<String, dynamic>{
          'wallet': <String, dynamic>{
            if (invalid != null) 'balance_cent': invalid,
          },
        }),
        throwsFormatException,
      );
      expect(
        () => GemProduct.fromJson(<String, dynamic>{
          if (invalid != null) 'base_gems_cent': invalid,
          'bonus_gems_cent': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => GemProduct.fromJson(<String, dynamic>{
          'base_gems_cent': 0,
          if (invalid != null) 'bonus_gems_cent': invalid,
        }),
        throwsFormatException,
      );
      expect(
        () => GemRecordItem.fromJson(<String, dynamic>{
          if (invalid != null) 'amount_cent': invalid,
        }),
        throwsFormatException,
      );
      expect(
        () => GemTask.fromJson(<String, dynamic>{
          if (invalid != null) 'reward_gems_cent': invalid,
        }),
        throwsFormatException,
      );
      expect(
        () => GemModel.fromJson(<String, dynamic>{
          if (invalid != null) 'estimated_next_message_gems_cent': invalid,
          'estimated_next_tick_gems_cent': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => GemModel.fromJson(<String, dynamic>{
          'estimated_next_message_gems_cent': 0,
          if (invalid != null) 'estimated_next_tick_gems_cent': invalid,
        }),
        throwsFormatException,
      );
      expect(
        () => ChatroomBalanceLow.fromEnvelope(
          ChatroomEnvelope(
            type: 'balance_low',
            payload: <String, dynamic>{
              if (invalid != null) 'balance_cent': invalid,
            },
          ),
        ),
        throwsFormatException,
      );
    }
  });
}

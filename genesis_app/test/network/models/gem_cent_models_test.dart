import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_records.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';

void main() {
  test('record split amounts preserve null and ignore the removed total', () {
    for (final amounts in [(null, null), (0, 0), (-100, -260), (null, -1)]) {
      final record = GemRecordItem.fromJson({
        'regular_amount_cent': amounts.$1,
        'membership_amount_cent': amounts.$2,
        'amount_cent': 'must not be read',
      });
      expect(record.regularAmountCent, amounts.$1);
      expect(record.membershipAmountCent, amounts.$2);
    }
  });

  test('both record split fields are required nullable integers', () {
    for (final field in ['regular_amount_cent', 'membership_amount_cent']) {
      for (final invalid in <Object?>[null, 1.5, '100', true]) {
        final json = <String, dynamic>{
          'regular_amount_cent': 0,
          'membership_amount_cent': 0,
        };
        if (invalid == null) {
          json.remove(field);
        } else {
          json[field] = invalid;
        }
        expect(() => GemRecordItem.fromJson(json), throwsFormatException);
      }
    }
  });

  Map<String, dynamic> quotation() => {
    'model_code': 'miranda',
    'title': 'Miranda',
    'tag': <String>[],
    'description': 'Model description',
    'estimated_next_message_gems_cent': 216,
    'estimated_next_tick_gems_cent': 300,
    'min_gems_cent': 216,
    'max_gems_cent': 483,
    'min_memory_tokens': 12400,
    'max_memory_tokens': 1000000,
  };

  test('model ranges parse without legacy range_text', () {
    final model = GemModel.fromJson(quotation());
    expect(model.minGemsCent, model.estimatedNextMessageGemsCent);
    expect(model.minGemsCent, 216);
    expect(model.maxGemsCent, 483);
    expect(model.minMemoryTokens, 12400);
    expect(model.maxMemoryTokens, 1000000);
  });

  test('model ranges reject missing, non-integer and inconsistent values', () {
    for (final field in [
      'min_gems_cent',
      'max_gems_cent',
      'min_memory_tokens',
      'max_memory_tokens',
    ]) {
      for (final value in <Object?>[null, '100', 100.0, true]) {
        final json = quotation();
        if (value == null) {
          json.remove(field);
        } else {
          json[field] = value;
        }
        expect(
          () => GemModel.fromJson(json),
          throwsFormatException,
          reason: '$field=$value',
        );
      }
    }
    for (final changes in <Map<String, dynamic>>[
      {'min_gems_cent': -1},
      {'max_gems_cent': 215},
      {'estimated_next_message_gems_cent': 217},
      {'min_memory_tokens': 0},
      {'max_memory_tokens': 12399},
    ]) {
      expect(
        () => GemModel.fromJson({...quotation(), ...changes}),
        throwsFormatException,
      );
    }
    expect(
      GemModel.fromJson({...quotation(), 'max_gems_cent': 216}).maxGemsCent,
      216,
    );
  });

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
      GemRecordItem.fromJson(<String, dynamic>{
        'regular_amount_cent': -400,
        'membership_amount_cent': 0,
      }).regularAmountCent,
      -400,
    );
    expect(
      GemTask.fromJson(<String, dynamic>{
        'reward_gems_cent': 2000,
      }).rewardGemsCent,
      2000,
    );
    final model = GemModel.fromJson(<String, dynamic>{
      'min_gems_cent': 400,
      'max_gems_cent': 483,
      'min_memory_tokens': 12400,
      'max_memory_tokens': 1000000,
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
          if (invalid != null) 'regular_amount_cent': invalid,
          'membership_amount_cent': 0,
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

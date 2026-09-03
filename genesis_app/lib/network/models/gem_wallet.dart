import '../../utils/gem_amount.dart';

class GemWallet {
  const GemWallet({required this.balanceCent});

  factory GemWallet.fromJson(Map<String, dynamic> json) {
    final rawWallet = json['wallet'];
    if (rawWallet is! Map) {
      throw const FormatException('Gem wallet payload is missing wallet');
    }
    return GemWallet(
      balanceCent: requireGemCent(
        rawWallet['balance_cent'],
        fieldName: 'wallet.balance_cent',
      ),
    );
  }

  final int balanceCent;
}

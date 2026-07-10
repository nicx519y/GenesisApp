class GemWallet {
  const GemWallet({required this.balance});

  factory GemWallet.fromJson(Map<String, dynamic> json) {
    final rawWallet = json['wallet'];
    if (rawWallet is! Map) {
      throw const FormatException('Gem wallet payload is missing wallet');
    }
    final rawBalance = rawWallet['balance'];
    if (rawBalance is int) return GemWallet(balance: rawBalance);
    if (rawBalance is num && rawBalance.isFinite) {
      return GemWallet(balance: rawBalance.toInt());
    }
    throw const FormatException('Gem wallet payload has an invalid balance');
  }

  final int balance;
}

import '../../network/models/membership_order_product.dart';

/// Store proof retained only to claim a guest purchase after reinstall.
/// It is independent of report retries and is kept in secure storage.
class MembershipGuestClaimProof {
  const MembershipGuestClaimProof({
    required this.provider,
    required this.storeProductId,
    required this.requestId,
    this.purchaseToken = '',
    this.transactionId = '',
    this.signedTransaction = '',
  });

  final MembershipProvider provider;
  final String storeProductId;
  final String requestId;
  final String purchaseToken;
  final String transactionId;
  final String signedTransaction;

  MembershipGuestClaimProof withSignedTransaction(String value) =>
      MembershipGuestClaimProof(
        provider: provider,
        storeProductId: storeProductId,
        requestId: requestId,
        purchaseToken: purchaseToken,
        transactionId: transactionId,
        signedTransaction: value,
      );

  Map<String, Object?> toJson() => {
    'provider': provider.name,
    'store_product_id': storeProductId,
    'request_id': requestId,
    if (provider == MembershipProvider.google) 'purchase_token': purchaseToken,
    if (provider == MembershipProvider.apple) 'transaction_id': transactionId,
    if (provider == MembershipProvider.apple && signedTransaction.isNotEmpty)
      'signed_transaction': signedTransaction,
  };

  factory MembershipGuestClaimProof.fromJson(Map<String, dynamic> json) {
    final provider = switch (json['provider']) {
      'google' => MembershipProvider.google,
      'apple' => MembershipProvider.apple,
      _ => throw const FormatException('Invalid guest claim proof provider'),
    };
    final storeId = json['store_product_id'];
    final requestId = json['request_id'];
    final token = json['purchase_token'] ?? '';
    final transaction = json['transaction_id'] ?? '';
    final signed = json['signed_transaction'] ?? '';
    if (storeId is! String ||
        storeId.isEmpty ||
        requestId is! String ||
        requestId.isEmpty ||
        requestId.length > 64 ||
        token is! String ||
        transaction is! String ||
        signed is! String ||
        (provider == MembershipProvider.google
            ? token.isEmpty
            : transaction.isEmpty)) {
      throw const FormatException('Incomplete guest claim proof');
    }
    return MembershipGuestClaimProof(
      provider: provider,
      storeProductId: storeId,
      requestId: requestId,
      purchaseToken: token,
      transactionId: transaction,
      signedTransaction: signed,
    );
  }
}

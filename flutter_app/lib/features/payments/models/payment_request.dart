import 'money.dart';

class PaymentRequest {
  const PaymentRequest({
    required this.transactionId,
    required this.merchantId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.reference,
  });

  final String transactionId;
  final String merchantId;
  final String customerId;
  final Money amount;
  final String paymentMethod;
  final String? reference;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'transaction_id': transactionId,
        'merchant_id': merchantId,
        'customer_id': customerId,
        'amount': amount.toJson(),
        'payment_method': paymentMethod,
        if (reference != null && reference!.trim().isNotEmpty)
          'reference': reference!.trim(),
      };
}

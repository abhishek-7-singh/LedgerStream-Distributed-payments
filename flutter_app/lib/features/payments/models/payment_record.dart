import 'money.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.transactionId,
    required this.merchantId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reason,
  });

  final String transactionId;
  final String merchantId;
  final String customerId;
  final Money amount;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? reason;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }

    return PaymentRecord(
      transactionId: json['transaction_id'] as String,
      merchantId: json['merchant_id'] as String,
      customerId: json['customer_id'] as String,
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
      createdAt: parseDate(json['created_at'] as String?),
      updatedAt: parseDate(json['updated_at'] as String?),
    );
  }
}

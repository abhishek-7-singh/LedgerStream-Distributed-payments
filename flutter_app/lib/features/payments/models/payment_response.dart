class PaymentResponse {
  const PaymentResponse({
    required this.transactionId,
    required this.status,
    this.reason,
  });

  final String transactionId;
  final String status;
  final String? reason;

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      transactionId: json['transaction_id'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'transaction_id': transactionId,
        'status': status,
        if (reason != null) 'reason': reason,
      };
}

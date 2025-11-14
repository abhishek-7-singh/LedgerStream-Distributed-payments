import 'payment_record.dart';

class PaymentCollection {
  const PaymentCollection({
    required this.items,
    required this.total,
  });

  final List<PaymentRecord> items;
  final int total;

  factory PaymentCollection.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? <dynamic>[];
    final items = itemsJson
        .map((item) => PaymentRecord.fromJson(item as Map<String, dynamic>))
        .toList();
    final totalRaw = json['total'];
    final total = totalRaw is int ? totalRaw : int.tryParse(totalRaw.toString()) ?? items.length;
    return PaymentCollection(items: items, total: total);
  }
}

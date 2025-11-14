class Money {
  const Money({
    required this.currency,
    required this.valueMinor,
  });

  final String currency;
  final int valueMinor;

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      currency: (json['currency'] as String).toUpperCase(),
      valueMinor: json['value_minor'] is int
          ? json['value_minor'] as int
          : int.tryParse(json['value_minor'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currency': currency.toUpperCase(),
        'value_minor': valueMinor,
      };

  double get valueMajor => valueMinor / 100;
}

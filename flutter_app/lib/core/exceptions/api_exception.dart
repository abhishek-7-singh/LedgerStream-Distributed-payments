class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.detail,
  });

  final int statusCode;
  final String message;
  final Object? detail;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions/api_exception.dart';
import '../../../core/http/rest_client.dart';
import '../data/payment_repository.dart';
import '../models/payment_collection.dart';
import '../models/payment_request.dart';
import '../models/payment_response.dart';

final restClientProvider = Provider<RestClient>((ref) {
  final client = RestClient();
  ref.onDispose(client.close);
  return client;
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final restClient = ref.watch(restClientProvider);
  return PaymentRepository(restClient: restClient);
});

final statusFilterProvider = StateProvider<String>((ref) => 'all');

final paymentsListProvider = FutureProvider.autoDispose<PaymentCollection>((ref) async {
  final repository = ref.watch(paymentRepositoryProvider);
  final status = ref.watch(statusFilterProvider);
  return repository.listPayments(status: status);
});

final lastSubmissionProvider = StateProvider<PaymentResponse?>((ref) => null);

final createPaymentProvider = FutureProvider.autoDispose.family<PaymentResponse, PaymentRequest>(
  (ref, request) async {
    final repository = ref.read(paymentRepositoryProvider);
    try {
      final response = await repository.createPayment(request);
      ref.invalidate(paymentsListProvider);
      ref.read(lastSubmissionProvider.notifier).state = response;
      return response;
    } on ApiException {
      rethrow;
    }
  },
);

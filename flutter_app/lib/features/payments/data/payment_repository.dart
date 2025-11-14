import '../../../core/config.dart';
import '../../../core/http/rest_client.dart';
import '../models/payment_collection.dart';
import '../models/payment_record.dart';
import '../models/payment_request.dart';
import '../models/payment_response.dart';
import 'payment_api.dart';

class PaymentRepository {
  PaymentRepository({RestClient? restClient, PaymentApi? api})
      : _api = api ?? PaymentApi(restClient ?? RestClient());

  final PaymentApi _api;

  Future<PaymentCollection> listPayments({String? status}) {
    final filter = status == null || status == 'all' ? null : status;
    return _api.listPayments(status: filter, limit: defaultPaymentsPageSize);
  }

  Future<PaymentRecord> getPayment(String transactionId) {
    return _api.getPayment(transactionId);
  }

  Future<PaymentResponse> createPayment(PaymentRequest request) {
    return _api.createPayment(request);
  }
}

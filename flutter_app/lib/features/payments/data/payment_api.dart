import 'dart:convert';

import '../../../core/http/rest_client.dart';
import '../models/payment_collection.dart';
import '../models/payment_record.dart';
import '../models/payment_request.dart';
import '../models/payment_response.dart';

class PaymentApi {
  PaymentApi(this._client);

  final RestClient _client;

  Future<PaymentCollection> listPayments({String? status, int? limit}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    if (limit != null) {
      query['limit'] = '$limit';
    }

    final json = await _client.get('/payments', queryParameters: query);
    return PaymentCollection.fromJson(json);
  }

  Future<PaymentRecord> getPayment(String transactionId) async {
    final json = await _client.get('/payments/$transactionId');
    return PaymentRecord.fromJson(json);
  }

  Future<PaymentResponse> createPayment(PaymentRequest payload) async {
    final json = await _client.post(
      '/payments',
      body: jsonEncode(payload.toJson()),
    );
    return PaymentResponse.fromJson(json);
  }
}

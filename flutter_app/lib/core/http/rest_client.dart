import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../exceptions/api_exception.dart';

class RestClient {
  RestClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _defaultHeaders = <String, String>{
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _client.get(uri, headers: _defaultHeaders);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _client.post(
      uri,
      headers: _defaultHeaders,
      body: body,
    );
    return _decodeResponse(response);
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    final base = Uri.parse(apiBaseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: _joinPaths(base.path, path),
      queryParameters: queryParameters?.isEmpty ?? true ? null : queryParameters,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    dynamic decoded;
    try {
      decoded = json.decode(body);
    } catch (_) {
      decoded = body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : response.reasonPhrase ?? 'Request failed';
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        detail: decoded,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(
      statusCode: 500,
      message: 'Unexpected response type',
    );
  }

  void close() => _client.close();

  String _joinPaths(String a, String b) {
    final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
    final right = b.startsWith('/') ? b.substring(1) : b;
    return '$left/$right';
  }
}

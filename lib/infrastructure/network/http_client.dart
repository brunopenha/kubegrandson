import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/utils/app_logger.dart';
import '../../core/constants/app_constants.dart';

class HttpClientService {
  final http.Client _client;
  final Duration timeout;

  HttpClientService({
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        timeout = timeout ?? AppConstants.defaultTimeout;

  Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? this.timeout);

      return _handleResponse(response);
    } catch (e, stackTrace) {
      AppLogger.error('HTTP GET error: $url', e, stackTrace);
      rethrow;
    }
  }

  Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? this.timeout);

      return _handleResponse(response);
    } catch (e, stackTrace) {
      AppLogger.error('HTTP POST error: $url', e, stackTrace);
      rethrow;
    }
  }

  Future<dynamic> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? this.timeout);

      return _handleResponse(response);
    } catch (e, stackTrace) {
      AppLogger.error('HTTP PUT error: $url', e, stackTrace);
      rethrow;
    }
  }

  Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? this.timeout);

      return _handleResponse(response);
    } catch (e, stackTrace) {
      AppLogger.error('HTTP DELETE error: $url', e, stackTrace);
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return json.decode(response.body);
      } catch (e) {
        return response.body;
      }
    } else {
      throw HttpException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

class HttpException implements Exception {
  final int statusCode;
  final String message;

  HttpException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'HttpException: $statusCode - $message';
}
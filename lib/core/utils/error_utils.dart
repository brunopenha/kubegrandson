import 'dart:io';
import 'package:dio/dio.dart';

bool isClusterOfflineError(Object error) {
  if (error is SocketException) {
    return true;
  }

  if (error is DioException) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  final msg = error.toString().toLowerCase();

  return msg.contains('connection refused') ||
      msg.contains('failed host lookup') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection timeout');
}

bool isAwsUnauthorizedError(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return true;
    }
  }

  final msg = error.toString().toLowerCase();
  return msg.contains('kubernetes api unauthorized') ||
      (msg.contains('status code of 401') && msg.contains('aws'));
}

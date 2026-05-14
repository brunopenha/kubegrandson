import 'dart:io';
import 'package:dio/dio.dart';


bool isClusterOfflineError(Object error){
  if(error is SocketException){
    return true;
  }

  if(error is DioException){
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
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/io.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:kubegrandson/core/network/app_proxy_configuration.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  final proxyUrl = Platform.environment['HTTPS_PROXY'] ??
      Platform.environment['https_proxy'] ??
      Platform.environment['HTTP_PROXY'] ??
      Platform.environment['http_proxy'] ??
      '';
  final noProxy = Platform.environment['NO_PROXY'] ??
      Platform.environment['no_proxy'] ??
      '';

  final kubernetes = k8s.Kubernetes();
  await kubernetes.initFromFile(p.join(home, '.kube', 'config'));
  final adapter = kubernetes.client.dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) {
    throw StateError('The Kubernetes client is not using an IO adapter.');
  }

  final configuration = AppProxyConfiguration(
    proxyUrl: proxyUrl,
    noProxy: noProxy,
  );
  final originalFactory = adapter.createHttpClient;
  adapter.createHttpClient = () {
    final client = originalFactory?.call() ?? HttpClient();
    client.findProxy = configuration.findProxy;
    return client;
  };

  final endpoint = Uri.parse(kubernetes.client.dio.options.baseUrl);
  print('Endpoint: $endpoint');
  print('Route: ${configuration.findProxy(endpoint)}');
  final version = await k8s.VersionApi(kubernetes.client.dio).getCode();
  print('Connected: ${version.data?.gitVersion}');
}

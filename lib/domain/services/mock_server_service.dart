import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/models/mock_service.dart';

class MockServerService {
  final Map<int, _MockServerBinding> _bindings = {};
  final StreamController<MockRequestLog> _logs = StreamController.broadcast();

  Stream<MockRequestLog> get logs => _logs.stream;
  Set<String> get runningServiceIds =>
      _bindings.values.expand((binding) => binding.endpoints.keys).toSet();

  Future<void> start(MockServiceConfig config) async {
    validate(config);
    if (runningServiceIds.contains(config.id)) return;
    final existing = _bindings[config.port];
    if (existing != null) {
      if (existing.useHttps != config.useHttps) {
        throw StateError(
            'Port ${config.port} is already running with a different HTTP/HTTPS mode');
      }
      if (config.useHttps &&
          (existing.certificatePath != config.certificatePath ||
              existing.privateKeyPath != config.privateKeyPath)) {
        throw StateError(
            'Endpoints on the same HTTPS port must use the same certificate and key');
      }
      existing.endpoints[config.id] = config;
      return;
    }
    final server = config.useHttps
        ? await _bindSecure(config)
        : await HttpServer.bind(InternetAddress.anyIPv4, config.port);
    final binding = _MockServerBinding(server, config);
    _bindings[config.port] = binding;
    unawaited(_serve(binding));
  }

  Future<HttpServer> _bindSecure(MockServiceConfig config) async {
    final context = SecurityContext();
    context.useCertificateChain(config.certificatePath);
    context.usePrivateKey(config.privateKeyPath);
    return HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      config.port,
      context,
    );
  }

  Future<void> _serve(_MockServerBinding binding) async {
    await for (final request in binding.server) {
      final body = await utf8.decoder.bind(request).join();
      MockServiceConfig? matchedEndpoint;
      Map<String, String>? pathParameters;
      for (final endpoint in binding.endpoints.values) {
        final parameters = matchPath(endpoint.path, request.uri.toString());
        final methodMatches =
            endpoint.method == 'ANY' || request.method == endpoint.method;
        if (parameters != null && methodMatches) {
          matchedEndpoint = endpoint;
          pathParameters = parameters;
          break;
        }
      }
      final status = matchedEndpoint?.statusCode ?? HttpStatus.notFound;
      if (matchedEndpoint != null) {
        for (final entry in matchedEndpoint.headers.entries) {
          request.response.headers.set(entry.key, entry.value);
        }
      }
      request.response.statusCode = status;
      request.response
          .write(matchedEndpoint?.body ?? 'No simulated route matched');
      await request.response.close();
      final receivedHeaders = <String, List<String>>{};
      request.headers.forEach((name, values) {
        receivedHeaders[name] = List<String>.from(values);
      });
      _logs.add(MockRequestLog(
        serviceId: matchedEndpoint?.id ??
            (binding.endpoints.isEmpty
                ? 'unmatched'
                : binding.endpoints.keys.first),
        timestamp: DateTime.now(),
        method: request.method,
        uri: request.uri,
        headers: receivedHeaders,
        body: body,
        responseStatus: status,
        message: matchedEndpoint?.logMessage ?? 'Route not found',
        pathParameters:
            matchedEndpoint == null ? const {} : pathParameters ?? const {},
      ));
    }
  }

  Future<void> stop(String id) async {
    int? emptyPort;
    for (final entry in _bindings.entries) {
      if (entry.value.endpoints.remove(id) != null) {
        if (entry.value.endpoints.isEmpty) emptyPort = entry.key;
        break;
      }
    }
    if (emptyPort != null) {
      final binding = _bindings.remove(emptyPort);
      await binding?.server.close(force: true);
    }
  }

  Future<void> stopAll() async {
    for (final binding in _bindings.values.toList()) {
      await binding.server.close(force: true);
    }
    _bindings.clear();
  }

  static void validate(MockServiceConfig config) {
    if (config.port < 1 || config.port > 65535) {
      throw const FormatException('Port must be between 1 and 65535');
    }
    if (!config.path.startsWith('/') && config.path != '*') {
      throw const FormatException('Path must start with /');
    }
    if (config.statusCode < 100 || config.statusCode > 599) {
      throw const FormatException('HTTP status must be between 100 and 599');
    }
    if (config.useHttps &&
        (config.certificatePath.trim().isEmpty ||
            config.privateKeyPath.trim().isEmpty)) {
      throw const FormatException(
          'HTTPS requires a PEM certificate chain and private key');
    }
  }

  static Map<String, String>? matchPath(
      String configuredPath, String requestPath) {
    if (configuredPath == '*') return const {};
    final configuredUri = Uri.parse(configuredPath);
    final requestUri = Uri.parse(requestPath);
    final configuredSegments = configuredUri.pathSegments;
    final requestSegments = requestUri.pathSegments;
    if (configuredSegments.length != requestSegments.length) return null;

    final parameters = <String, String>{};
    for (var index = 0; index < configuredSegments.length; index++) {
      final configured = configuredSegments[index];
      final requested = requestSegments[index];
      if (!_matchValue(configured, requested, parameters)) {
        return null;
      }
    }

    if (configuredUri.hasQuery) {
      for (final entry in configuredUri.queryParameters.entries) {
        final requested = requestUri.queryParameters[entry.key];
        if (requested == null ||
            !_matchValue(entry.value, requested, parameters)) {
          return null;
        }
      }
    }
    return parameters;
  }

  static bool _matchValue(
      String configured, String requested, Map<String, String> parameters) {
    if (configured == '*') return true;
    final colonParameter = configured.startsWith(':') && configured.length > 1;
    final braceParameter = configured.startsWith('{') &&
        configured.endsWith('}') &&
        configured.length > 2;
    if (colonParameter || braceParameter) {
      final name = colonParameter
          ? configured.substring(1)
          : configured.substring(1, configured.length - 1);
      parameters[name] = requested;
      return true;
    }
    return configured == requested;
  }

  Future<void> dispose() async {
    await stopAll();
    await _logs.close();
  }
}

class _MockServerBinding {
  _MockServerBinding(this.server, MockServiceConfig firstEndpoint)
      : useHttps = firstEndpoint.useHttps,
        certificatePath = firstEndpoint.certificatePath,
        privateKeyPath = firstEndpoint.privateKeyPath,
        endpoints = {firstEndpoint.id: firstEndpoint};

  final HttpServer server;
  final bool useHttps;
  final String certificatePath;
  final String privateKeyPath;
  final Map<String, MockServiceConfig> endpoints;
}

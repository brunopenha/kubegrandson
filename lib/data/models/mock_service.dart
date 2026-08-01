class MockServiceConfig {
  const MockServiceConfig({
    required this.id,
    required this.name,
    required this.port,
    this.method = 'ANY',
    this.path = '/',
    this.statusCode = 200,
    this.headers = const {'content-type': 'application/json; charset=utf-8'},
    this.body = '{"token":"fixed-token","message":"Login successful"}',
    this.logMessage = 'Simulated response sent',
    bool useHttps = false,
    String certificatePath = '',
    String privateKeyPath = '',
  })  : _useHttps = useHttps,
        _certificatePath = certificatePath,
        _privateKeyPath = privateKeyPath;

  final String id;
  final String name;
  final int port;
  final String method;
  final String path;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final String logMessage;
  // Nullable backing fields keep objects created before the HTTPS feature
  // compatible across Flutter hot reloads and older imported state.
  final bool? _useHttps;
  final String? _certificatePath;
  final String? _privateKeyPath;

  bool get useHttps => _useHttps ?? false;
  String get certificatePath => _certificatePath ?? '';
  String get privateKeyPath => _privateKeyPath ?? '';

  MockServiceConfig copyWithServer({
    required int port,
    required bool useHttps,
    required String certificatePath,
    required String privateKeyPath,
  }) =>
      MockServiceConfig(
        id: id,
        name: name,
        port: port,
        method: method,
        path: path,
        statusCode: statusCode,
        headers: headers,
        body: body,
        logMessage: logMessage,
        useHttps: useHttps,
        certificatePath: certificatePath,
        privateKeyPath: privateKeyPath,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'port': port,
        'method': method,
        'path': path,
        'statusCode': statusCode,
        'headers': headers,
        'body': body,
        'logMessage': logMessage,
        'useHttps': useHttps,
        'certificatePath': certificatePath,
        'privateKeyPath': privateKeyPath,
      };

  factory MockServiceConfig.fromJson(Map<String, dynamic> json) {
    final port = json['port'];
    final statusCode = json['statusCode'];
    if (json['name'] is! String || port is! num || statusCode is! num) {
      throw const FormatException(
          'Service name, port and statusCode are required');
    }
    return MockServiceConfig(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String,
      port: port.toInt(),
      method: (json['method'] ?? 'ANY').toString().toUpperCase(),
      path: (json['path'] ?? '/').toString(),
      statusCode: statusCode.toInt(),
      headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
      body: (json['body'] ?? '').toString(),
      logMessage: (json['logMessage'] ?? '').toString(),
      useHttps: json['useHttps'] == true,
      certificatePath: (json['certificatePath'] ?? '').toString(),
      privateKeyPath: (json['privateKeyPath'] ?? '').toString(),
    );
  }
}

class MockRequestLog {
  const MockRequestLog({
    required this.serviceId,
    required this.timestamp,
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.responseStatus,
    required this.message,
    this.pathParameters = const {},
  });

  final String serviceId;
  final DateTime timestamp;
  final String method;
  final Uri uri;
  final Map<String, List<String>> headers;
  final String body;
  final int responseStatus;
  final String message;
  final Map<String, String> pathParameters;
}

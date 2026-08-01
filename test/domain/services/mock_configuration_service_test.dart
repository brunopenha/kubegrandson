import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/models/mock_service.dart';
import 'package:kubegrandson/domain/services/mock_configuration_service.dart';

void main() {
  final service = MockConfigurationService();

  test('exports and imports multiple mock services', () {
    final input = [
      const MockServiceConfig(
          id: 'login',
          name: 'Login',
          port: 8081,
          method: 'POST',
          path: '/login',
          statusCode: 201,
          headers: {'x-mock': 'yes'},
          body: '{"token":"fixed"}',
          logMessage: 'login ok'),
      const MockServiceConfig(
          id: 'catalog',
          name: 'Catalog',
          port: 8082,
          method: 'GET',
          path: '/items',
          statusCode: 200,
          useHttps: true,
          certificatePath: '/certs/mock.pem',
          privateKeyPath: '/certs/mock-key.pem'),
    ];

    final result = service.import(service.export(input));

    expect(result, hasLength(2));
    expect(result.first.name, 'Login');
    expect(result.first.headers, {'x-mock': 'yes'});
    expect(result.last.port, 8082);
    expect(result.last.useHttps, isTrue);
    expect(result.last.certificatePath, '/certs/mock.pem');
  });

  test('rejects JSON without services array', () {
    expect(() => service.import('{"version":1}'), throwsFormatException);
  });
}

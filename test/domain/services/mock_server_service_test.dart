import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/models/mock_service.dart';
import 'package:kubegrandson/domain/services/mock_server_service.dart';

void main() {
  test('returns configured response and records the complete request',
      () async {
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    final server = MockServerService();
    addTearDown(server.dispose);
    final config = MockServiceConfig(
      id: 'login',
      name: 'Login',
      port: port,
      method: 'POST',
      path: '/login',
      statusCode: 201,
      headers: const {
        'content-type': 'application/json',
        'x-simulated': 'true'
      },
      body: '{"token":"fixed-token"}',
      logMessage: 'Login simulated',
    );
    await server.start(config);
    final logFuture = server.logs.first;

    final client = HttpClient();
    final request = await client.post('127.0.0.1', port, '/login?source=test');
    request.headers.set('x-request-id', 'abc');
    request.write('{"user":"developer"}');
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    final log = await logFuture;
    client.close();

    expect(response.statusCode, 201);
    expect(response.headers.value('x-simulated'), 'true');
    expect(responseBody, '{"token":"fixed-token"}');
    expect(log.method, 'POST');
    expect(log.uri.queryParameters['source'], 'test');
    expect(log.headers['x-request-id'], ['abc']);
    expect(log.body, '{"user":"developer"}');
    expect(log.message, 'Login simulated');
  });

  test('returns 404 when method or path does not match', () async {
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    final server = MockServerService();
    addTearDown(server.dispose);
    await server.start(MockServiceConfig(
        id: 'one',
        name: 'One',
        port: port,
        method: 'GET',
        path: '/expected',
        statusCode: 200));

    final client = HttpClient();
    final response =
        await (await client.get('127.0.0.1', port, '/other')).close();
    await response.drain<void>();
    client.close();
    expect(response.statusCode, 404);
  });

  test('routes multiple endpoints through one server and port', () async {
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    final server = MockServerService();
    addTearDown(server.dispose);
    await server.start(MockServiceConfig(
        id: 'orders',
        name: 'Orders',
        port: port,
        method: 'GET',
        path: '/orders/:id',
        statusCode: 200,
        body: 'order'));
    await server.start(MockServiceConfig(
        id: 'customers',
        name: 'Customers',
        port: port,
        method: 'POST',
        path: '/customers',
        statusCode: 201,
        body: 'customer'));

    final client = HttpClient();
    final orderResponse =
        await (await client.get('127.0.0.1', port, '/orders/42')).close();
    final orderBody = await utf8.decoder.bind(orderResponse).join();
    final customerResponse =
        await (await client.post('127.0.0.1', port, '/customers')).close();
    final customerBody = await utf8.decoder.bind(customerResponse).join();
    client.close();

    expect(orderResponse.statusCode, 200);
    expect(orderBody, 'order');
    expect(customerResponse.statusCode, 201);
    expect(customerBody, 'customer');
    expect(server.runningServiceIds, containsAll(['orders', 'customers']));
  });

  test('validates port, path and HTTP status', () {
    expect(
        () => MockServerService.validate(
            const MockServiceConfig(id: 'x', name: 'X', port: 0)),
        throwsFormatException);
    expect(
        () => MockServerService.validate(
            const MockServiceConfig(id: 'x', name: 'X', port: 80, path: 'bad')),
        throwsFormatException);
    expect(
        () => MockServerService.validate(const MockServiceConfig(
            id: 'x', name: 'X', port: 80, statusCode: 99)),
        throwsFormatException);
    expect(
        () => MockServerService.validate(const MockServiceConfig(
            id: 'x', name: 'X', port: 443, useHttps: true)),
        throwsFormatException);
  });

  test('matches and captures dynamic path segments', () {
    expect(
        MockServerService.matchPath('/api/v1/credentialRequests/:id',
            '/api/v1/credentialRequests/890139119779'),
        {'id': '890139119779'});
    expect(
        MockServerService.matchPath(
            '/users/{userId}/orders/:orderId', '/users/42/orders/ABC'),
        {'userId': '42', 'orderId': 'ABC'});
    expect(
        MockServerService.matchPath(
            '/api/v1/credentialRequests/:id', '/api/v1/other/10'),
        isNull);
  });

  test('matches literal and dynamic query parameters in any order', () {
    final parameters = MockServerService.matchPath(
        '/api/v2/gw/:customer_id/orders?pageSize=25&productList=:product_id&statusList=:status_id&sort=-orderId',
        '/api/v2/gw/utopia/orders?sort=-orderId&statusList=SCHEDULED&productList=PASSPORT_ORDINARY&pageSize=25');

    expect(parameters, {
      'customer_id': 'utopia',
      'product_id': 'PASSPORT_ORDINARY',
      'status_id': 'SCHEDULED',
    });
    expect(
        MockServerService.matchPath(
            '/orders?pageSize=25', '/orders?pageSize=50'),
        isNull);
  });
}

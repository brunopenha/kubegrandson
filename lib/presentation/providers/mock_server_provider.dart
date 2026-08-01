import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/mock_service.dart';
import '../../domain/services/mock_server_service.dart';

class MockServerState {
  const MockServerState(
      {this.services = const [],
      this.runningIds = const {},
      this.logs = const []});
  final List<MockServiceConfig> services;
  final Set<String> runningIds;
  final List<MockRequestLog> logs;

  MockServerState copyWith(
          {List<MockServiceConfig>? services,
          Set<String>? runningIds,
          List<MockRequestLog>? logs}) =>
      MockServerState(
        services: services ?? this.services,
        runningIds: runningIds ?? this.runningIds,
        logs: logs ?? this.logs,
      );
}

class MockServerNotifier extends StateNotifier<MockServerState> {
  MockServerNotifier(this._server) : super(const MockServerState()) {
    _subscription = _server.logs.listen((log) {
      state = state.copyWith(logs: [log, ...state.logs].take(500).toList());
    });
  }

  final MockServerService _server;
  late final StreamSubscription<MockRequestLog> _subscription;

  void add(MockServiceConfig config) =>
      state = state.copyWith(services: [...state.services, config]);

  Future<void> update(MockServiceConfig config) async {
    await stop(config.id);
    state = state.copyWith(
        services: state.services
            .map((item) => item.id == config.id ? config : item)
            .toList());
  }

  Future<void> updateServer(
    Set<String> endpointIds, {
    required int port,
    required bool useHttps,
    required String certificatePath,
    required String privateKeyPath,
  }) async {
    for (final id in endpointIds) {
      await _server.stop(id);
    }
    state = state.copyWith(
      services: state.services.map((item) {
        if (!endpointIds.contains(item.id)) return item;
        return item.copyWithServer(
          port: port,
          useHttps: useHttps,
          certificatePath: certificatePath,
          privateKeyPath: privateKeyPath,
        );
      }).toList(),
      runningIds: {...state.runningIds}..removeAll(endpointIds),
    );
  }

  Future<void> replaceAll(List<MockServiceConfig> services) async {
    await _server.stopAll();
    state = MockServerState(services: services);
  }

  Future<void> remove(String id) async {
    await stop(id);
    state = state.copyWith(
        services: state.services.where((item) => item.id != id).toList());
  }

  Future<void> start(MockServiceConfig config) async {
    await _server.start(config);
    state = state.copyWith(runningIds: {...state.runningIds, config.id});
  }

  Future<void> stop(String id) async {
    await _server.stop(id);
    state = state.copyWith(runningIds: {...state.runningIds}..remove(id));
  }

  void clearLogs() => state = state.copyWith(logs: const []);

  @override
  void dispose() {
    _subscription.cancel();
    _server.dispose();
    super.dispose();
  }
}

final mockServerProvider =
    StateNotifierProvider<MockServerNotifier, MockServerState>((ref) {
  return MockServerNotifier(MockServerService());
});

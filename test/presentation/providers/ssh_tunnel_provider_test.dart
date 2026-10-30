import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';
import 'package:kubegrandson/domain/services/ssh_tunnel_service.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';
import 'package:kubegrandson/presentation/providers/ssh_tunnel_provider.dart';

class RecordingKubernetesService extends KubernetesService {
  String? path;
  String? appliedProxy;
  String? appliedNoProxy;
  @override
  String get defaultKubeconfigPath => '/home/local/.kube/config';
  @override
  Future<void> initialize(
      {String? kubeconfigPath,
      bool verifyConnection = true,
      String? proxyUrl,
      String? noProxy}) async {
    path = kubeconfigPath;
    appliedProxy = proxyUrl;
    appliedNoProxy = noProxy;
  }
}

class ControlledTunnel extends SshTunnelService {
  void activate() {
    kubeconfigPath = '/temporary/ssh/config';
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'uses direct SSH endpoint and restores the default kubeconfig after disconnect',
      () async {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
    final service = RecordingKubernetesService();
    final tunnel = ControlledTunnel();
    final container = ProviderContainer(overrides: [
      kubernetesServiceProvider.overrideWithValue(service),
      sshTunnelProvider.overrideWith((_) => tunnel),
    ]);
    addTearDown(container.dispose);
    container.listen(initializeProvider, (_, __) {});
    await container.read(initializeProvider.future);
    expect(service.path, '/home/local/.kube/config');
    tunnel.activate();
    await container.read(initializeProvider.future);
    expect(service.path, '/temporary/ssh/config');
    expect(service.appliedProxy, '');
    expect(service.appliedNoProxy, '127.0.0.1,localhost');
    await tunnel.disconnect();
    await container.read(initializeProvider.future);
    expect(service.path, '/home/local/.kube/config');
  });
}

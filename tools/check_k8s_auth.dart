import 'package:k8s/k8s.dart' as k8s;

// dart run .\check_k8s_auth.dart
Future<void> main() async {
  final kube = k8s.Kubernetes();
  await kube.initFromFile(
    r'C:\Users\t0309990\.kube\config',
    validateConfig: true,
    throwExceptions: true,
  );

  final version = await k8s.VersionApi(kube.client.dio).getCode();
  print('Connected. Version: ${version.data?.gitVersion}');

  final ns = await k8s.CoreV1Api(kube.client.dio).listNamespace();
  final names = (ns.data?.items ?? []).map((e) => e.metadata?.name).toList();
  print('Namespaces: $names');
}

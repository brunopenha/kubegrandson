import 'package:k8s/k8s.dart' as k8s;
import '../../core/utils/app_logger.dart';
import '../../data/models/kubernetes/pod.dart' as models;

class KubernetesService {
  k8s.ApiClient? _client;

  Future<void> initialize(String kubeconfigPath) async {
    try {
      final kubernetes = k8s.Kubernetes();
      await kubernetes.initFromFile(kubeconfigPath);
      _client = kubernetes.client;

      final versionApi = k8s.VersionApi(_client!.dio);
      final version = await versionApi.getCode();

      AppLogger.info('Kubernetes client initialized');
      AppLogger.info('Version: ${version.data?.gitVersion}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Kubernetes client', e, stackTrace);
      rethrow;
    }
  }

  Future<List<models.KubePod>> fetchPods(String namespace) async {
    final api = k8s.CoreV1Api(_client!.dio);
    final response = namespace == 'all'
        ? await api.listPodForAllNamespaces()
        : await api.listNamespacedPod(namespace: namespace);

    final items = response.data?.items ?? [];
    return items.map((pod) {
      return models.KubePod(
        name: pod.metadata?.name ?? 'Unknown',
        namespace: pod.metadata?.namespace ?? namespace,
        uid: pod.metadata?.uid,
        phase: pod.status?.phase ?? 'Unknown',
        podIP: pod.status?.podIP,
        nodeName: pod.spec?.nodeName,
        creationTimestamp: pod.metadata?.creationTimestamp,
        labels: pod.metadata?.labels?.cast<String, String>(),
        annotations: pod.metadata?.annotations?.cast<String, String>(),
        containerStatuses: pod.status?.containerStatuses?.map((cs) {
          return models.ContainerStatus(
            name: cs.name,
            ready: cs.ready,
            restartCount: cs.restartCount,
            image: cs.image,
            state: cs.state,
          );
        }).toList(),
        restartCount: pod.status?.containerStatuses
            ?.fold(0, (sum, cs) => sum! + cs.restartCount) ??
            0,
      );
    }).toList();
  }

  Future<List<String>> fetchNamespaces() async {
    final api = k8s.CoreV1Api(_client!.dio);
    final response = await api.listNamespace();
    return response.data?.items
        ?.map((ns) => ns.metadata?.name ?? '')
        .where((name) => name.isNotEmpty)
        .toList() ??
        [];
  }

  Future<String> readPodLogs(String namespace, String podName) async {
    final api = k8s.CoreV1Api(_client!.dio);
    final response = await api.readNamespacedPodLog(
      name: podName,
      namespace: namespace,
      follow: true,
    );
    return response.data ?? '';
  }

  Future<void> deletePod(String namespace, String podName) async {
    final api = k8s.CoreV1Api(_client!.dio);
    await api.deleteNamespacedPod(name: podName, namespace: namespace);
    AppLogger.info('Deleted pod: $namespace/$podName');
  }

  void dispose() {
    _client = null; // no explicit close needed
  }

  Stream<String> streamLogs({
    required String namespace,
    required String podName,
    String? containerName,
    int? tailLines,
    bool follow = true,
  }) async* {
    final api = k8s.CoreV1Api(_client!.dio);
    final response = await api.readNamespacedPodLog(
      name: podName,
      namespace: namespace,
      container: containerName,
      follow: follow,
      tailLines: tailLines,
    );
    yield response.data ?? '';
  }
}
import 'package:http/http.dart';
import 'package:kubernetes/kubernetes.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/kubernetes/pod.dart';
import 'package:kubernetes/kubernetes.dart' as k8s;


class KubernetesService {
  Client? _client;
  String? _currentContext;

  Future<void> initialize(String kubeconfigPath) async {
    try {
      final config = Configuration.fromKubeconfig(kubeconfigPath);
      _client = Client(config);
      _currentContext = config.currentContext;
      AppLogger.info('Kubernetes client initialized: $_currentContext');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Kubernetes client', e, stackTrace);
      rethrow;
    }
  }

  Future<List<KubePod>> fetchPods(String namespace) async {
    if (_client == null) {
      throw Exception('Kubernetes client not initialized');
    }

    try {
      final pods = namespace == 'all'
          ? await _client!.listPodForAllNamespaces()
          : await _client!.listNamespacedPod(namespace);

      return pods.items.map((pod) {
        return KubePod(
          name: pod.metadata?.name ?? 'Unknown',
          namespace: pod.metadata?.namespace ?? namespace,
          uid: pod.metadata?.uid,
          phase: pod.status?.phase ?? 'Unknown',
          podIP: pod.status?.podIP,
          nodeName: pod.spec?.nodeName,
          creationTimestamp: pod.metadata?.creationTimestamp,
          labels: pod.metadata?.labels?.cast<String, String>(),
          annotations: pod.metadata?.annotations?.cast<String, String>(),
          containerStatuses: pod.status?.containerStatuses
              ?.map((cs) => ContainerStatus(
            name: cs.name,
            ready: cs.ready,
            restartCount: cs.restartCount,
            image: cs.image,
            state: cs.state != null
                ? ContainerState(
              running: cs.state!.running != null
                  ? ContainerStateRunning(
                  startedAt: cs.state!.running!.startedAt)
                  : null,
              waiting: cs.state!.waiting != null
                  ? ContainerStateWaiting(
                  reason: cs.state!.waiting!.reason,
                  message: cs.state!.waiting!.message)
                  : null,
              terminated: cs.state!.terminated != null
                  ? ContainerStateTerminated(
                  reason: cs.state!.terminated!.reason,
                  message: cs.state!.terminated!.message,
                  exitCode: cs.state!.terminated!.exitCode,
                  startedAt: cs.state!.terminated!.startedAt,
                  finishedAt:
                  cs.state!.terminated!.finishedAt)
                  : null,
            )
                : null,
          ))
              .toList(),
          restartCount: pod.status?.containerStatuses?.fold(
              0, (sum, cs) => sum + cs.restartCount) ??
              0,
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to fetch pods', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> fetchNamespaces() async {
    if (_client == null) {
      throw Exception('Kubernetes client not initialized');
    }

    try {
      final namespaces = await _client!.listNamespace();

      return namespaces.items
          .map((ns) => ns.metadata?.name ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to fetch namespaces', e, stackTrace);
      rethrow;
    }
  }

  Stream<String> streamLogs({
    required String namespace,
    required String podName,
    String? containerName,
    int? tailLines,
    bool follow = true,
  }) async* {
    if (_client == null) {
      throw Exception('Kubernetes client not initialized');
    }

    try {
      final logStream = _client!.readNamespacedPodLog(
        podName,
        namespace,
        container: containerName,
        follow: follow,
        tailLines: tailLines,
      );

      await for (final log in logStream) {
        yield log;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to stream logs', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deletePod(String namespace, String podName) async {
    if (_client == null) {
      throw Exception('Kubernetes client not initialized');
    }

    try {
      final api = CoreV1Api(_client!);
      await api.deleteNamespacedPod(podName, namespace);
      AppLogger.info('Deleted pod: $namespace/$podName');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete pod', e, stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}
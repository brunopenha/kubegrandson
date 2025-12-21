import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:path/path.dart' as p;
import '../../core/utils/app_logger.dart';
import '../../data/models/kubernetes/pod.dart' as models;

class KubernetesService {
  k8s.ApiClient? _client;

  final k8s.Kubernetes Function() _kubernetesFactory;
  final k8s.CoreV1Api Function(Dio dio) _coreV1ApiFactory;
  final k8s.VersionApi Function(Dio dio) _versionApiFactory;
  final String? Function() _homeDirResolver;

  KubernetesService({
    k8s.ApiClient? client,
    k8s.Kubernetes Function()? kubernetesFactory,
    k8s.CoreV1Api Function(Dio dio)? coreV1ApiFactory,
    k8s.VersionApi Function(Dio dio)? versionApiFactory,
    String? Function()? homeDirResolver,
  })  : _client = client,
        _kubernetesFactory = kubernetesFactory ?? (() => k8s.Kubernetes()),
        _coreV1ApiFactory = coreV1ApiFactory ?? ((dio) => k8s.CoreV1Api(dio)),
        _versionApiFactory = versionApiFactory ?? ((dio) => k8s.VersionApi(dio)),
        _homeDirResolver = homeDirResolver ??
            (() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']);

  Future<void> initialize({String? kubeconfigPath}) async {
    try {
      final kubernetes = _kubernetesFactory();

      // If no path provided, resolve default ~/.kube/config cross‑platform
      if (kubeconfigPath == null) {
        final home = _homeDirResolver();
        final defaultPath = p.join(home!, '.kube', 'config');
        await kubernetes.initFromFile(defaultPath);
      } else {
        await kubernetes.initFromFile(kubeconfigPath);
      }

      _client = kubernetes.client;
      _client!.dio.options
        ..connectTimeout = const Duration(seconds: 30) // allow more time to connect
        ..receiveTimeout = Duration.zero; // disable receive timeout for streaming

      final versionApi = _versionApiFactory(_client!.dio);
      final version = await versionApi.getCode();

      AppLogger.info('Kubernetes client initialized');
      AppLogger.info('Version: ${version.data?.gitVersion}');
      AppLogger.info('KubernetesService.client: $_client');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Kubernetes client', e, stackTrace);
      rethrow;
    }
  }

  Future<List<models.KubePod>> fetchPods(String namespace) async {
    final api = _coreV1ApiFactory(_client!.dio);
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
        restartCount:
            pod.status?.containerStatuses?.fold(0, (sum, cs) => sum! + cs.restartCount) ?? 0,
      );
    }).toList();
  }

  Future<List<String>> fetchNamespaces() async {
    print('fetchNamespaces called');
    final response = await _client?.getCoreV1Api().listNamespace();
    final namespaces = response?.data?.items ?? [];
    final names = namespaces.map((ns) {
      final name = ns.metadata?.name ?? '';
      return name;
    }).toList();
    return names;
  }

  Future<String> readPodLogs(String namespace, String podName) async {
    final api = _coreV1ApiFactory(_client!.dio);
    final response = await api.readNamespacedPodLog(
      name: podName,
      namespace: namespace,
      follow: true,
    );
    return response.data ?? '';
  }

  Future<void> deletePod(String namespace, String podName) async {
    final api = _coreV1ApiFactory(_client!.dio);
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
    final dio = _client!.dio;

    final response = await dio.get<ResponseBody>(
      '/api/v1/namespaces/$namespace/pods/$podName/log',
      queryParameters: {
        if (containerName != null) 'container': containerName,
        'follow': follow,
        if (tailLines != null) 'tailLines': tailLines,
      },
      options: Options(responseType: ResponseType.stream),
    );

    final byteStream = response.data!.stream; // Stream<Uint8List>

    // Convert bytes -> String -> lines
    final lineStream = byteStream
        .transform(StreamTransformer.fromBind(
          (s) => s.cast<List<int>>().transform(utf8.decoder),
        ))
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final formatted = '[${DateTime.now().toIso8601String()}] $line';
      yield formatted;
    }
  }
}
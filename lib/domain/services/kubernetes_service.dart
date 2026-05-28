import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:path/path.dart' as p;
import '../../core/utils/app_logger.dart';
import '../../data/models/kubernetes/deployment.dart' as deployments;
import '../../data/models/kubernetes/config_map.dart' as config_maps;
import '../../data/models/kubernetes/pod.dart' as models;
import '../../data/models/kubernetes/service.dart' as services;

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
        _versionApiFactory =
            versionApiFactory ?? ((dio) => k8s.VersionApi(dio)),
        _homeDirResolver = homeDirResolver ??
            (() =>
                Platform.environment['HOME'] ??
                Platform.environment['USERPROFILE']);

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
        ..connectTimeout =
            const Duration(seconds: 30) // allow more time to connect
        ..receiveTimeout =
            Duration.zero; // disable receive timeout for streaming

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
        restartCount: pod.status?.containerStatuses
                ?.fold(0, (sum, cs) => sum! + cs.restartCount) ??
            0,
      );
    }).toList();
  }

  Future<List<services.KubeService>> fetchServices(String namespace) async {
    final api = _coreV1ApiFactory(_client!.dio);
    final response = namespace == 'all'
        ? await api.listServiceForAllNamespaces()
        : await api.listNamespacedService(namespace: namespace);

    final items = response.data?.items ?? [];
    return items.map((service) {
      final serviceNamespace = service.metadata?.namespace ?? namespace;
      final ports = service.spec?.ports?.map((port) {
        return services.ServicePort(
          name: port.name ?? '',
          port: port.port,
          targetPort: int.tryParse('${port.targetPort}') ?? port.port,
          protocol: port.protocol ?? 'TCP',
          nodePort: port.nodePort,
        );
      }).toList();

      return services.KubeService(
        name: service.metadata?.name ?? 'Unknown',
        namespace: serviceNamespace,
        uid: service.metadata?.uid,
        type: service.spec?.type ?? 'ClusterIP',
        clusterIP: service.spec?.clusterIP,
        externalIPs: service.spec?.externalIPs,
        ports: ports,
        creationTimestamp: service.metadata?.creationTimestamp,
        labels: service.metadata?.labels?.cast<String, String>(),
        annotations: service.metadata?.annotations?.cast<String, String>(),
        selector: service.spec?.selector?.cast<String, String>(),
      );
    }).toList();
  }

  Future<List<deployments.KubeDeployment>> fetchDeployments(
    String namespace,
  ) async {
    final response = await _client!.dio.get<Map<String, dynamic>>(
      namespace == 'all'
          ? '/apis/apps/v1/deployments'
          : '/apis/apps/v1/namespaces/$namespace/deployments',
    );

    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items.map((item) {
      final json = item as Map<String, dynamic>;
      final metadata = json['metadata'] as Map<String, dynamic>? ?? const {};
      final spec = json['spec'] as Map<String, dynamic>? ?? const {};
      final status = json['status'] as Map<String, dynamic>? ?? const {};
      return deployments.KubeDeployment(
        name: metadata['name']?.toString() ?? 'Unknown',
        namespace: metadata['namespace']?.toString() ?? namespace,
        uid: metadata['uid']?.toString(),
        replicas: spec['replicas'] as int? ?? 0,
        readyReplicas: status['readyReplicas'] as int? ?? 0,
        availableReplicas: status['availableReplicas'] as int? ?? 0,
        unavailableReplicas: status['unavailableReplicas'] as int? ?? 0,
        creationTimestamp: metadata['creationTimestamp'] == null
            ? null
            : DateTime.tryParse(metadata['creationTimestamp'].toString()),
        labels: (metadata['labels'] as Map?)?.cast<String, String>(),
        annotations: (metadata['annotations'] as Map?)?.cast<String, String>(),
        updatedReplicas: status['updatedReplicas'] as int? ?? 0,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> readDeploymentSpec({
    required String namespace,
    required String name,
  }) async {
    final response = await _client!.dio.get<Map<String, dynamic>>(
      '/apis/apps/v1/namespaces/$namespace/deployments/$name',
    );
    return (response.data?['spec'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
  }

  Future<void> updateDeploymentSpec({
    required String namespace,
    required String name,
    required Map<String, dynamic> spec,
  }) async {
    await _client!.dio.patch<Map<String, dynamic>>(
      '/apis/apps/v1/namespaces/$namespace/deployments/$name',
      data: {'spec': spec},
      options: Options(contentType: 'application/merge-patch+json'),
    );
  }

  Future<List<config_maps.KubeConfigMap>> fetchConfigMaps(
    String namespace,
  ) async {
    final api = _coreV1ApiFactory(_client!.dio);
    final response = namespace == 'all'
        ? await api.listConfigMapForAllNamespaces()
        : await api.listNamespacedConfigMap(namespace: namespace);

    final items = response.data?.items ?? [];
    return items.map((configMap) {
      return config_maps.KubeConfigMap(
        name: configMap.metadata?.name ?? 'Unknown',
        namespace: configMap.metadata?.namespace ?? namespace,
        uid: configMap.metadata?.uid,
        creationTimestamp: configMap.metadata?.creationTimestamp,
        labels: configMap.metadata?.labels?.cast<String, String>(),
        annotations: configMap.metadata?.annotations?.cast<String, String>(),
        data: configMap.data?.cast<String, String>(),
        binaryData: configMap.binaryData?.cast<String, String>(),
      );
    }).toList();
  }

  Future<config_maps.KubeConfigMap> updateConfigMapData({
    required String namespace,
    required String name,
    required Map<String, String> data,
  }) async {
    final response = await _client!.dio.patch<Map<String, dynamic>>(
      '/api/v1/namespaces/$namespace/configmaps/$name',
      data: {'data': data},
      options: Options(contentType: 'application/merge-patch+json'),
    );

    final json = response.data ?? const <String, dynamic>{};
    final metadata = json['metadata'] as Map<String, dynamic>? ?? const {};
    return config_maps.KubeConfigMap(
      name: metadata['name']?.toString() ?? name,
      namespace: metadata['namespace']?.toString() ?? namespace,
      uid: metadata['uid']?.toString(),
      labels: (metadata['labels'] as Map?)?.cast<String, String>(),
      annotations: (metadata['annotations'] as Map?)?.cast<String, String>(),
      data: (json['data'] as Map?)?.cast<String, String>(),
      binaryData: (json['binaryData'] as Map?)?.cast<String, String>(),
    );
  }

  Future<List<String>> fetchNamespaces() async {
    AppLogger.info('Fetching namespaces');
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

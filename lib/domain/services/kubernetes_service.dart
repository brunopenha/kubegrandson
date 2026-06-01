import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:kubeconfig/kubeconfig.dart' as kubeconfig;
import 'package:path/path.dart' as p;
import '../../core/utils/app_logger.dart';
import '../../data/models/app_state/cluster_context.dart';
import '../../data/models/kubernetes/deployment.dart' as deployments;
import '../../data/models/kubernetes/config_map.dart' as config_maps;
import '../../data/models/kubernetes/pod.dart' as models;
import '../../data/models/kubernetes/service.dart' as services;

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class AwsEksContextInfo {
  final String contextName;
  final String region;
  final String accountId;
  final String clusterName;

  const AwsEksContextInfo({
    required this.contextName,
    required this.region,
    required this.accountId,
    required this.clusterName,
  });
}

class KubernetesService {
  k8s.ApiClient? _client;
  String? _kubeconfigPath;
  String? _currentContextName;
  final Map<String, String> _awsProfileByAccount = <String, String>{};

  final k8s.Kubernetes Function() _kubernetesFactory;
  final k8s.CoreV1Api Function(Dio dio) _coreV1ApiFactory;
  final k8s.VersionApi Function(Dio dio) _versionApiFactory;
  final String? Function() _homeDirResolver;
  final ProcessRunner _processRunner;

  KubernetesService({
    k8s.ApiClient? client,
    k8s.Kubernetes Function()? kubernetesFactory,
    k8s.CoreV1Api Function(Dio dio)? coreV1ApiFactory,
    k8s.VersionApi Function(Dio dio)? versionApiFactory,
    String? Function()? homeDirResolver,
    ProcessRunner? processRunner,
  })  : _client = client,
        _kubernetesFactory = kubernetesFactory ?? (() => k8s.Kubernetes()),
        _coreV1ApiFactory = coreV1ApiFactory ?? ((dio) => k8s.CoreV1Api(dio)),
        _versionApiFactory =
            versionApiFactory ?? ((dio) => k8s.VersionApi(dio)),
        _homeDirResolver = homeDirResolver ??
            (() =>
                Platform.environment['HOME'] ??
                Platform.environment['USERPROFILE']),
        _processRunner = processRunner ??
            ((executable, arguments) => Process.run(executable, arguments));

  String? get currentContextName => _currentContextName;
  AwsEksContextInfo? get currentAwsEksContextInfo {
    final contextName = _currentContextName;
    if (contextName == null || contextName.isEmpty) {
      return null;
    }
    return _parseAwsEksContext(contextName);
  }

  Future<String?> getCurrentAwsProfile() async {
    final info = currentAwsEksContextInfo;
    if (info == null) {
      return null;
    }

    final kubeconfigPath = _kubeconfigPath ?? _resolveDefaultKubeconfigPath();
    final config = await _readKubeconfig(kubeconfigPath);
    final exec = _currentContextExec(config, info.contextName);
    if (exec == null) {
      return null;
    }

    final fromArgs = _profileFromExecArgs(exec.args);
    if (fromArgs != null && fromArgs.isNotEmpty) {
      return fromArgs;
    }

    for (final entry in exec.env ?? const <kubeconfig.ExecEnv>[]) {
      final name = entry.name;
      if (name == 'AWS_PROFILE' || name == 'AWS_DEFAULT_PROFILE') {
        final value = entry.value;
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }

    return _resolveAwsProfileForAccount(info.accountId);
  }

  Future<void> refreshAwsSsoCredentials({
    required String profile,
    String? region,
    String? clusterName,
    String? accountId,
  }) async {
    final info = currentAwsEksContextInfo;
    final resolvedRegion = (region ?? info?.region ?? '').trim();
    final resolvedClusterName = (clusterName ?? info?.clusterName ?? '').trim();

    if (resolvedRegion.isEmpty || resolvedClusterName.isEmpty) {
      throw Exception(
        'Region and cluster name are required to refresh AWS credentials.',
      );
    }

    await _runProcess(
      operationName: 'aws sso login',
      executable: 'aws',
      arguments: ['sso', 'login', '--profile', profile],
    );

    await _runProcess(
      operationName: 'aws eks update-kubeconfig',
      executable: 'aws',
      arguments: [
        'eks',
        'update-kubeconfig',
        '--region',
        resolvedRegion,
        '--name',
        resolvedClusterName,
        '--profile',
        profile,
      ],
    );

    final resolvedAccountId = (accountId != null && accountId.trim().isNotEmpty)
        ? accountId.trim()
        : await _awsAccountForProfile(profile);
    if (resolvedAccountId != null && resolvedAccountId.isNotEmpty) {
      _awsProfileByAccount[resolvedAccountId] = profile;
      final contextName =
          'arn:aws:eks:$resolvedRegion:$resolvedAccountId:cluster/$resolvedClusterName';
      await _switchContextIfPresent(contextName);
    }

    await initialize(
      kubeconfigPath: _kubeconfigPath,
      verifyConnection: false,
    );
  }

  Future<void> initialize({
    String? kubeconfigPath,
    bool verifyConnection = true,
  }) async {
    try {
      final kubernetes = _kubernetesFactory();

      // If no path provided, resolve default ~/.kube/config cross‑platform
      final resolvedPath =
          kubeconfigPath ?? _kubeconfigPath ?? _resolveDefaultKubeconfigPath();
      if (await File(resolvedPath).exists()) {
        await _ensureAwsExecEnvironment(resolvedPath);
      }
      await kubernetes.initFromFile(resolvedPath);

      _client = kubernetes.client;
      _kubeconfigPath = resolvedPath;
      _client!.dio.options
        ..connectTimeout =
            const Duration(seconds: 30) // allow more time to connect
        ..receiveTimeout =
            Duration.zero; // disable receive timeout for streaming

      try {
        _currentContextName = await File(resolvedPath).exists()
            ? await _readCurrentContextName(resolvedPath)
            : null;
      } catch (e, stackTrace) {
        _currentContextName = null;
        AppLogger.warning(
          'Unable to determine current context from kubeconfig.',
          e,
          stackTrace,
        );
      }

      if (verifyConnection) {
        final versionApi = _versionApiFactory(_client!.dio);
        final version = await versionApi.getCode();
        AppLogger.info('Version: ${version.data?.gitVersion}');
      } else {
        AppLogger.info(
          'Kubernetes client initialized without connectivity check.',
        );
      }

      AppLogger.info('Kubernetes client initialized');
      AppLogger.info('KubernetesService.client: $_client');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Kubernetes client', e, stackTrace);
      rethrow;
    }
  }

  Future<List<ClusterContext>> fetchContexts() async {
    final kubeconfigPath = _kubeconfigPath ?? _resolveDefaultKubeconfigPath();
    final config = await _readKubeconfig(kubeconfigPath);
    final activeContext = config.currentContext;

    return (config.contexts ?? <kubeconfig.NamedContext>[]).map((named) {
      final context = named.context;
      return ClusterContext(
        name: named.name ?? '',
        cluster: context?.cluster,
        user: context?.authInfo,
        namespace: context?.namespace ?? 'default',
        isActive: named.name == activeContext,
      );
    }).toList();
  }

  Future<void> switchContext(String contextName) async {
    final kubeconfigPath = _kubeconfigPath ?? _resolveDefaultKubeconfigPath();
    final config = await _readKubeconfig(kubeconfigPath);

    final contextExists =
        (config.contexts ?? <kubeconfig.NamedContext>[]).any((named) {
      return named.name == contextName;
    });

    if (!contextExists) {
      throw Exception('Context "$contextName" not found in kubeconfig.');
    }

    final updatedConfig = config.copyWith(currentContext: contextName);
    await File(kubeconfigPath).writeAsString(updatedConfig.toYaml());
    await initialize(
      kubeconfigPath: kubeconfigPath,
      verifyConnection: false,
    );
  }

  Future<void> _switchContextIfPresent(String contextName) async {
    final kubeconfigPath = _kubeconfigPath ?? _resolveDefaultKubeconfigPath();
    final config = await _readKubeconfig(kubeconfigPath);
    final contextExists = (config.contexts ?? const <kubeconfig.NamedContext>[])
        .any((named) => named.name == contextName);
    if (!contextExists) {
      return;
    }

    final updatedConfig = config.copyWith(currentContext: contextName);
    await File(kubeconfigPath).writeAsString(updatedConfig.toYaml());
  }

  Future<List<models.KubePod>> fetchPods(String namespace) async {
    final response = await _withAuthRetry(() async {
      final api = _coreV1ApiFactory(_client!.dio);
      return namespace == 'all'
          ? await api.listPodForAllNamespaces()
          : await api.listNamespacedPod(namespace: namespace);
    });

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
    final response = await _withAuthRetry(() async {
      final api = _coreV1ApiFactory(_client!.dio);
      return namespace == 'all'
          ? await api.listServiceForAllNamespaces()
          : await api.listNamespacedService(namespace: namespace);
    });

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
    final response = await _withAuthRetry(
      () => _client!.dio.get<Map<String, dynamic>>(
        namespace == 'all'
            ? '/apis/apps/v1/deployments'
            : '/apis/apps/v1/namespaces/$namespace/deployments',
      ),
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
    final response = await _withAuthRetry(() async {
      final api = _coreV1ApiFactory(_client!.dio);
      return namespace == 'all'
          ? await api.listConfigMapForAllNamespaces()
          : await api.listNamespacedConfigMap(namespace: namespace);
    });

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
    final response = await _withAuthRetry(
      () => _client!.getCoreV1Api().listNamespace(),
    );
    final namespaces = response.data?.items ?? [];
    final names = namespaces.map((ns) {
      final name = ns.metadata?.name ?? '';
      return name;
    }).toList();
    return names;
  }

  Future<String> readPodLogs(String namespace, String podName) async {
    final response = await _withAuthRetry(() async {
      final api = _coreV1ApiFactory(_client!.dio);
      return api.readNamespacedPodLog(
        name: podName,
        namespace: namespace,
        follow: true,
      );
    });
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

  String _resolveDefaultKubeconfigPath() {
    final home = _homeDirResolver();
    if (home == null || home.isEmpty) {
      throw Exception(
        'Unable to resolve home directory for default kubeconfig path.',
      );
    }

    return p.join(home, '.kube', 'config');
  }

  Future<kubeconfig.Kubeconfig> _readKubeconfig(String kubeconfigPath) async {
    final content = await File(kubeconfigPath).readAsString();
    return kubeconfig.Kubeconfig.fromYaml(content);
  }

  Future<String?> _readCurrentContextName(String kubeconfigPath) async {
    final config = await _readKubeconfig(kubeconfigPath);
    return config.currentContext;
  }

  Future<void> _ensureAwsExecEnvironment(String kubeconfigPath) async {
    final config = await _readKubeconfig(kubeconfigPath);
    final contextName = config.currentContext;
    if (contextName == null) {
      return;
    }
    final info = _parseAwsEksContext(contextName);
    if (info == null) {
      return;
    }

    final profile = await _resolveAwsProfileForAccount(info.accountId);
    if (profile == null || profile.isEmpty) {
      return;
    }

    final authInfos = config.authInfos ?? const <kubeconfig.NamedAuthInfo>[];
    final userName = _currentContextUserName(config, contextName);
    if (userName == null || userName.isEmpty) {
      return;
    }
    var changed = false;
    final updatedAuthInfos = authInfos.map((namedAuthInfo) {
      if (namedAuthInfo.name != userName) {
        return namedAuthInfo;
      }

      final user = namedAuthInfo.user;
      final exec = user?.exec;
      final command = exec?.command?.toLowerCase().trim();
      final args = exec?.args ?? const <String>[];
      final isAwsEksExec = command == 'aws' &&
          args.contains('eks') &&
          args.contains('get-token');

      if (!isAwsEksExec || exec == null || user == null) {
        return namedAuthInfo;
      }

      final mergedEnv = _mergeExecEnv(
        exec.env,
        <String, String>{
          'AWS_PROFILE': profile,
          'AWS_DEFAULT_PROFILE': profile,
        },
      );
      final mergedArgs = _ensureAwsProfileArg(exec.args, profile);

      if (_execEnvEquals(exec.env, mergedEnv) &&
          _stringListEquals(exec.args, mergedArgs)) {
        return namedAuthInfo;
      }

      final updatedUser = user.copyWith(
        exec: exec.copyWith(
          env: mergedEnv,
          args: mergedArgs,
        ),
      );
      changed = true;
      return namedAuthInfo.copyWith(user: updatedUser);
    }).toList();

    if (!changed) {
      return;
    }

    final updatedConfig = config.copyWith(authInfos: updatedAuthInfos);
    await File(kubeconfigPath).writeAsString(updatedConfig.toYaml());
    AppLogger.info(
      'Configured AWS exec env for context "$contextName" with profile "$profile".',
    );
  }

  AwsEksContextInfo? _parseAwsEksContext(String contextName) {
    final match = RegExp(r'^arn:aws:eks:([^:]+):(\d{12}):cluster\/(.+)$')
        .firstMatch(contextName);
    if (match == null) {
      return null;
    }

    return AwsEksContextInfo(
      contextName: contextName,
      region: match.group(1)!,
      accountId: match.group(2)!,
      clusterName: match.group(3)!,
    );
  }

  String? _currentContextUserName(
    kubeconfig.Kubeconfig config,
    String contextName,
  ) {
    final contexts = config.contexts ?? const <kubeconfig.NamedContext>[];
    for (final namedContext in contexts) {
      if (namedContext.name == contextName) {
        return namedContext.context?.authInfo;
      }
    }
    return null;
  }

  kubeconfig.Exec? _currentContextExec(
    kubeconfig.Kubeconfig config,
    String contextName,
  ) {
    final userName = _currentContextUserName(config, contextName);
    if (userName == null || userName.isEmpty) {
      return null;
    }

    final authInfos = config.authInfos ?? const <kubeconfig.NamedAuthInfo>[];
    for (final namedAuthInfo in authInfos) {
      if (namedAuthInfo.name == userName) {
        return namedAuthInfo.user?.exec;
      }
    }
    return null;
  }

  Future<String?> _resolveAwsProfileForAccount(String accountId) async {
    final cached = _awsProfileByAccount[accountId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final preferredFromEnv = Platform.environment['AWS_PROFILE'] ??
        Platform.environment['AWS_DEFAULT_PROFILE'];
    if (preferredFromEnv != null && preferredFromEnv.isNotEmpty) {
      final envAccount = await _awsAccountForProfile(preferredFromEnv);
      if (envAccount == accountId) {
        _awsProfileByAccount[accountId] = preferredFromEnv;
        return preferredFromEnv;
      }
    }

    final profilesResult = await _processRunner('aws', [
      'configure',
      'list-profiles',
    ]);
    if (profilesResult.exitCode != 0) {
      return null;
    }

    final profiles = profilesResult.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final profile in profiles) {
      final profileAccount = await _awsAccountForProfile(profile);
      if (profileAccount == accountId) {
        _awsProfileByAccount[accountId] = profile;
        return profile;
      }
    }

    return null;
  }

  Future<String?> _awsAccountForProfile(String profile) async {
    final result = await _processRunner('aws', [
      'sts',
      'get-caller-identity',
      '--profile',
      profile,
      '--output',
      'json',
    ]);
    if (result.exitCode != 0) {
      return null;
    }

    try {
      final data =
          json.decode(result.stdout.toString()) as Map<String, dynamic>;
      return data['Account']?.toString();
    } catch (_) {
      return null;
    }
  }

  List<kubeconfig.ExecEnv> _mergeExecEnv(
    List<kubeconfig.ExecEnv>? current,
    Map<String, String> updates,
  ) {
    final envMap = <String, String>{};
    for (final item in current ?? const <kubeconfig.ExecEnv>[]) {
      final name = item.name;
      final value = item.value;
      if (name == null || name.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      if (name == 'AWS_ACCESS_KEY_ID' ||
          name == 'AWS_SECRET_ACCESS_KEY' ||
          name == 'AWS_SESSION_TOKEN') {
        continue;
      }
      envMap[name] = value;
    }

    envMap.addAll(updates);
    return envMap.entries
        .map((entry) => kubeconfig.ExecEnv(name: entry.key, value: entry.value))
        .toList();
  }

  List<String> _ensureAwsProfileArg(List<String>? args, String profile) {
    final current = List<String>.from(args ?? const <String>[]);
    final profileIndex = current.indexOf('--profile');
    if (profileIndex >= 0) {
      if (profileIndex + 1 < current.length &&
          current[profileIndex + 1].isNotEmpty) {
        return current;
      }
      if (profileIndex + 1 < current.length) {
        current[profileIndex + 1] = profile;
      } else {
        current.add(profile);
      }
      return current;
    }

    return <String>['--profile', profile, ...current];
  }

  String? _profileFromExecArgs(List<String>? args) {
    final current = args ?? const <String>[];
    final profileIndex = current.indexOf('--profile');
    if (profileIndex < 0 || profileIndex + 1 >= current.length) {
      return null;
    }
    return current[profileIndex + 1];
  }

  Future<void> _runProcess({
    required String operationName,
    required String executable,
    required List<String> arguments,
  }) async {
    final result = await _processRunner(executable, arguments);
    if (result.exitCode == 0) {
      return;
    }

    final stderr = result.stderr.toString().trim();
    throw Exception(
      '$operationName failed (exit ${result.exitCode})'
      '${stderr.isEmpty ? '' : ': $stderr'}',
    );
  }

  bool _execEnvEquals(
    List<kubeconfig.ExecEnv>? a,
    List<kubeconfig.ExecEnv>? b,
  ) {
    final aMap = <String, String>{};
    for (final item in a ?? const <kubeconfig.ExecEnv>[]) {
      final name = item.name;
      if (name == null || name.isEmpty) {
        continue;
      }
      aMap[name] = item.value ?? '';
    }

    final bMap = <String, String>{};
    for (final item in b ?? const <kubeconfig.ExecEnv>[]) {
      final name = item.name;
      if (name == null || name.isEmpty) {
        continue;
      }
      bMap[name] = item.value ?? '';
    }

    if (aMap.length != bMap.length) {
      return false;
    }

    for (final entry in aMap.entries) {
      if (bMap[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  bool _stringListEquals(List<String>? a, List<String>? b) {
    final left = a ?? const <String>[];
    final right = b ?? const <String>[];
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  Stream<String> streamLogs({
    required String namespace,
    required String podName,
    String? containerName,
    int? tailLines,
    bool follow = true,
  }) async* {
    final dio = _client!.dio;

    final response = await _withAuthRetry(
      () => dio.get<ResponseBody>(
        '/api/v1/namespaces/$namespace/pods/$podName/log',
        queryParameters: {
          if (containerName != null) 'container': containerName,
          'follow': follow,
          if (tailLines != null) 'tailLines': tailLines,
        },
        options: Options(responseType: ResponseType.stream),
      ),
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

  Future<T> _withAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;

      AppLogger.warning(
        'Received HTTP 401 from Kubernetes API. Reinitializing client to refresh credentials.',
      );
      await initialize(
        kubeconfigPath: _kubeconfigPath,
        verifyConnection: false,
      );

      try {
        return await action();
      } on DioException catch (retryError) {
        if (retryError.response?.statusCode != 401) rethrow;
        final context = _currentContextName ?? 'unknown';
        throw Exception(
          'Kubernetes API unauthorized for context "$context". '
          'For EKS, ensure kubeconfig was generated with the correct profile '
          '(example: aws eks update-kubeconfig --region eu-west-1 --name <cluster> --profile <profile>) '
          'or set AWS_PROFILE for the process running the app.',
        );
      }
    }
  }
}

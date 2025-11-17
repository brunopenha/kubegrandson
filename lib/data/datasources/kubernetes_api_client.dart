import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/app_logger.dart';
import '../models/kubernetes/pod.dart';
import '../models/kubernetes/namespace.dart';
import '../models/kubernetes/deployment.dart';
import '../models/kubernetes/service.dart';
import '../models/app_state/cluster_context.dart';

class KubernetesApiClient {
  String? _apiServer;
  String? _token;
  String? _currentContext;
  String? _currentNamespace;

  bool get isConnected => _apiServer != null && _token != null;
  String? get currentContext => _currentContext;
  String? get currentNamespace => _currentNamespace;

  Future<void> loadKubeConfig() async {
    try {
      final config = await AppConfig.getInstance();
      final configFile = File(config.kubeConfigPath);

      if (!await configFile.exists()) {
        throw Exception('Kubeconfig file not found at ${config.kubeConfigPath}');
      }

      final content = await configFile.readAsString();
      final yamlDoc = loadYaml(content);

      // Get current context
      _currentContext = yamlDoc['current-context'];

      // Find context details
      final contexts = yamlDoc['contexts'] as List;
      final contextData = contexts.firstWhere(
            (c) => c['name'] == _currentContext,
        orElse: () => throw Exception('Context not found'),
      );

      final clusterName = contextData['context']['cluster'];
      final userName = contextData['context']['user'];
      _currentNamespace = contextData['context']['namespace'] ?? 'default';

      // Find cluster details
      final clusters = yamlDoc['clusters'] as List;
      final clusterData = clusters.firstWhere(
            (c) => c['name'] == clusterName,
        orElse: () => throw Exception('Cluster not found'),
      );

      _apiServer = clusterData['cluster']['server'];

      // Find user details
      final users = yamlDoc['users'] as List;
      final userData = users.firstWhere(
            (u) => u['name'] == userName,
        orElse: () => throw Exception('User not found'),
      );

      _token = userData['user']['token'];

      AppLogger.info('Loaded kubeconfig for context: $_currentContext');
    } catch (e, stack) {
      AppLogger.error('Failed to load kubeconfig', e, stack);
      rethrow;
    }
  }

  Future<List<ClusterContext>> getContexts() async {
    try {
      final config = await AppConfig.getInstance();
      final configFile = File(config.kubeConfigPath);

      if (!await configFile.exists()) {
        return [];
      }

      final content = await configFile.readAsString();
      final yamlDoc = loadYaml(content);

      final currentContext = yamlDoc['current-context'];
      final contexts = yamlDoc['contexts'] as List;

      return contexts.map((c) {
        final name = c['name'] as String;
        return ClusterContext(
          name: name,
          cluster: c['context']['cluster'],
          user: c['context']['user'],
          namespace: c['context']['namespace'] ?? 'default',
          isActive: name == currentContext,
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get contexts', e, stack);
      return [];
    }
  }

  Future<void> switchContext(String contextName) async {
    try {
      final config = await AppConfig.getInstance();
      final configFile = File(config.kubeConfigPath);

      final content = await configFile.readAsString();
      final yamlDoc = loadYaml(content);

      // Verify context exists
      final contexts = yamlDoc['contexts'] as List;
      final contextExists = contexts.any((c) => c['name'] == contextName);

      if (!contextExists) {
        throw Exception('Context $contextName not found');
      }

      // Update current-context in config file
      final updatedContent = content.replaceFirst(
        RegExp(r'current-context:.*'),
        'current-context: $contextName',
      );

      await configFile.writeAsString(updatedContent);
      await loadKubeConfig();

      AppLogger.info('Switched to context: $contextName');
    } catch (e, stack) {
      AppLogger.error('Failed to switch context', e, stack);
      rethrow;
    }
  }

  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<KubeNamespace>> getNamespaces() async {
    try {
      final url = '$_apiServer/api/v1/namespaces';
      final response = await _makeRequest(url);

      final data = jsonDecode(response);
      final items = data['items'] as List;

      return items.map((item) {
        return KubeNamespace(
          name: item['metadata']['name'],
          uid: item['metadata']['uid'],
          // status: item['status']['phase'] ?? 'Active',
          creationTimestamp: DateTime.parse(item['metadata']['creationTimestamp']),
          labels: Map<String, String>.from(item['metadata']['labels'] ?? {}),
          annotations: Map<String, String>.from(item['metadata']['annotations'] ?? {}),
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to fetch namespaces', e, stack);
      rethrow;
    }
  }

  Future<List<KubePod>> getPods(String namespace) async {
    try {
      final url = '$_apiServer/api/v1/namespaces/$namespace/pods';
      final response = await _makeRequest(url);

      final data = jsonDecode(response);
      final items = data['items'] as List;

      return items.map((item) {
        final containerStatuses = (item['status']['containerStatuses'] as List?)
            ?.map((cs) => ContainerStatus(
          name: cs['name'],
          ready: cs['ready'],
          restartCount: cs['restartCount'],
          image: cs['image'],
        ))
            .toList();

        return KubePod(
          name: item['metadata']['name'],
          namespace: namespace,
          uid: item['metadata']['uid'],
          phase: item['status']['phase'] ?? 'Unknown',
          podIP: item['status']['podIP'],
          nodeName: item['spec']['nodeName'],
          creationTimestamp: DateTime.parse(item['metadata']['creationTimestamp']),
          labels: Map<String, String>.from(item['metadata']['labels'] ?? {}),
          annotations: Map<String, String>.from(item['metadata']['annotations'] ?? {}),
          containerStatuses: containerStatuses,
          restartCount: containerStatuses?.fold(0, (sum, cs) => sum! + cs.restartCount) ?? 0,
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to fetch pods', e, stack);
      rethrow;
    }
  }

  Future<List<KubeDeployment>> getDeployments(String namespace) async {
    try {
      final url = '$_apiServer/apis/apps/v1/namespaces/$namespace/deployments';
      final response = await _makeRequest(url);

      final data = jsonDecode(response);
      final items = data['items'] as List;

      return items.map((item) {
        return KubeDeployment(
          name: item['metadata']['name'],
          namespace: namespace,
          uid: item['metadata']['uid'],
          replicas: item['spec']['replicas'],
          availableReplicas: item['status']['availableReplicas'],
          readyReplicas: item['status']['readyReplicas'],
          // updatedReplicas: item['status']['updatedReplicas'],
          creationTimestamp: DateTime.parse(item['metadata']['creationTimestamp']),
          labels: Map<String, String>.from(item['metadata']['labels'] ?? {}),
          annotations: Map<String, String>.from(item['metadata']['annotations'] ?? {}),
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to fetch deployments', e, stack);
      rethrow;
    }
  }

  Future<List<KubeService>> getServices(String namespace) async {
    try {
      final url = '$_apiServer/api/v1/namespaces/$namespace/services';
      final response = await _makeRequest(url);

      final data = jsonDecode(response);
      final items = data['items'] as List;

      return items.map((item) {
        final ports = (item['spec']['ports'] as List?)
            ?.map((p) => ServicePort(
          name: p['name'],
          port: p['port'],
          targetPort: p['targetPort'],
          protocol: p['protocol'] ?? 'TCP',
          nodePort: p['nodePort'],
        ))
            .toList();

        return KubeService(
          name: item['metadata']['name'],
          namespace: namespace,
          uid: item['metadata']['uid'],
          type: item['spec']['type'] ?? 'ClusterIP',
          clusterIP: item['spec']['clusterIP'],
          externalIPs: (item['spec']['externalIPs'] as List?)?.cast<String>(),
          ports: ports,
          creationTimestamp: DateTime.parse(item['metadata']['creationTimestamp']),
          labels: Map<String, String>.from(item['metadata']['labels'] ?? {}),
          annotations: Map<String, String>.from(item['metadata']['annotations'] ?? {}),
          selector: Map<String, String>.from(item['spec']['selector'] ?? {}),
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to fetch services', e, stack);
      rethrow;
    }
  }

  Stream<String> streamPodLogs({
    required String namespace,
    required String podName,
    String? containerName,
    bool follow = true,
    int? tailLines,
  }) async* {
    try {
      var url = '$_apiServer/api/v1/namespaces/$namespace/pods/$podName/log?follow=$follow';
      if (containerName != null) {
        url += '&container=$containerName';
      }
      if (tailLines != null) {
        url += '&tailLines=$tailLines';
      }

      final uri = Uri.parse(url);
      final request = await HttpClient().getUrl(uri);
      request.headers.set('Authorization', 'Bearer $_token');

      final response = await request.close();

      await for (final chunk in response.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.isNotEmpty) {
            yield line;
          }
        }
      }
    } catch (e, stack) {
      AppLogger.error('Failed to stream pod logs', e, stack);
      rethrow;
    }
  }

  Future<String> _makeRequest(String url) async {
    final uri = Uri.parse(url);
    final request = await HttpClient().getUrl(uri);

    _getHeaders().forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('API request failed with status ${response.statusCode}');
    }

    return await response.transform(utf8.decoder).join();
  }
}
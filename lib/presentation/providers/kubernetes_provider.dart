import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local_storage_client.dart';
import '../../data/models/app_state/cluster_context.dart';
import '../../data/models/kubernetes/config_map.dart';
import '../../data/models/kubernetes/deployment.dart';
import '../../data/models/kubernetes/pod.dart';
import '../../data/models/kubernetes/service.dart';
import '../../domain/services/kubernetes_service.dart';
import 'settings_notifier.dart';

final initializeProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(kubernetesServiceProvider);
  final storage = await LocalStorageClient.getInstance();
  final kubeconfigPath = await storage.getKubeConfigPath();
  await service.initialize(
    kubeconfigPath: (kubeconfigPath == null || kubeconfigPath.trim().isEmpty)
        ? null
        : kubeconfigPath.trim(),
    verifyConnection: false,
  );
});

final kubernetesServiceProvider = Provider<KubernetesService>((ref) {
  final service = KubernetesService();
  ref.onDispose(() => service.dispose());
  return service;
});

final namespacesProvider = FutureProvider<List<String>>((ref) async {
  await ref.watch(initializeProvider.future); // wait until init completes
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchNamespaces();
});

final contextsProvider = FutureProvider<List<ClusterContext>>((ref) async {
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchContexts();
});

final selectedNamespaceProvider = StateProvider<String>((ref) {
  return ref.watch(
    settingsProvider.select((settings) => settings.defaultNamespace),
  );
});

final selectedPodNamesProvider = StateProvider<Set<String>>((ref) => {});
final podLogSearchQueryProvider = StateProvider<String>((ref) => '');
final podLogSearchMatchesProvider = StateProvider<Set<String>?>((ref) => null);
final isSearchingPodLogsProvider = StateProvider<bool>((ref) => false);

Set<String> reconcilePodSelection(
  Set<String> selectedPodNames,
  Iterable<KubePod> pods,
) {
  final existingPodNames = pods.map((pod) => pod.name).toSet();
  return selectedPodNames.intersection(existingPodNames);
}

String podGroupName(KubePod pod) {
  final labels = pod.labels ?? const <String, String>{};

  return labels['app.kubernetes.io/name'] ??
      labels['app'] ??
      labels['k8s-app'] ??
      labels['component'] ??
      replicaSetPrefix(pod.name);
}

String replicaSetPrefix(String podName) {
  final parts = podName.split('-');
  if (parts.length >= 3) {
    return parts.take(parts.length - 2).join('-');
  }

  return podName;
}

final autoRefreshIntervalSecondsProvider = StateProvider<int>((ref) {
  return ref.watch(
    settingsProvider.select((settings) => settings.autoRefreshIntervalSeconds),
  );
});

final podsProvider =
    FutureProvider.family<List<KubePod>, String>((ref, ns) async {
  await ref.watch(initializeProvider.future); // wait until init completes
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchPods(ns);
});

final servicesProvider =
    FutureProvider.family<List<KubeService>, String>((ref, ns) async {
  await ref.watch(initializeProvider.future); // wait until init completes
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchServices(ns);
});

final deploymentsProvider =
    FutureProvider.family<List<KubeDeployment>, String>((ref, ns) async {
  await ref.watch(initializeProvider.future); // wait until init completes
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchDeployments(ns);
});

final configMapsProvider =
    FutureProvider.family<List<KubeConfigMap>, String>((ref, ns) async {
  await ref.watch(initializeProvider.future); // wait until init completes
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchConfigMaps(ns);
});

final currentPodsProvider = FutureProvider<List<KubePod>>((ref) async {
  final namespace = ref.watch(selectedNamespaceProvider);
  return ref.watch(podsProvider(namespace).future);
});

void refreshKubernetesResources(dynamic ref) {
  final namespace = ref.read(selectedNamespaceProvider);
  ref.invalidate(contextsProvider);
  ref.invalidate(namespacesProvider);
  ref.invalidate(podsProvider(namespace));
  ref.invalidate(servicesProvider(namespace));
  ref.invalidate(deploymentsProvider(namespace));
  ref.invalidate(configMapsProvider(namespace));
  ref.invalidate(currentPodsProvider);
}

void refreshCurrentPods(WidgetRef ref) {
  refreshKubernetesResources(ref);
}

Future<void> searchLogsAcrossPods(WidgetRef ref) async {
  final query = ref.read(podLogSearchQueryProvider).trim();
  if (query.isEmpty) {
    ref.read(podLogSearchMatchesProvider.notifier).state = null;
    return;
  }

  ref.read(isSearchingPodLogsProvider.notifier).state = true;
  try {
    final pods = await ref.read(currentPodsProvider.future);
    final service = ref.read(kubernetesServiceProvider);
    final normalizedQuery = query.toLowerCase();
    final results = await Future.wait(
      pods.map((pod) async {
        try {
          final matches = await service
              .streamLogs(
                namespace: pod.namespace,
                podName: pod.name,
                tailLines: 1000,
                follow: false,
              )
              .any((line) => line.toLowerCase().contains(normalizedQuery));
          return matches ? pod.name : null;
        } catch (_) {
          return null;
        }
      }),
    );

    if (ref.read(podLogSearchQueryProvider).trim() == query) {
      final matches = results.whereType<String>().toSet();
      ref.read(podLogSearchMatchesProvider.notifier).state = matches;
      final selected = ref.read(selectedPodNamesProvider);
      ref.read(selectedPodNamesProvider.notifier).state =
          selected.intersection(matches);
    }
  } finally {
    ref.read(isSearchingPodLogsProvider.notifier).state = false;
  }
}

void clearPodLogSearch(WidgetRef ref) {
  ref.read(podLogSearchQueryProvider.notifier).state = '';
  ref.read(podLogSearchMatchesProvider.notifier).state = null;
}

Future<void> switchKubernetesContext(
  WidgetRef ref, {
  required String contextName,
  String? namespace,
}) async {
  final service = ref.read(kubernetesServiceProvider);
  await service.switchContext(contextName);
  ref.read(selectedNamespaceProvider.notifier).state = namespace ?? 'default';
  ref.read(selectedPodNamesProvider.notifier).state = {};
  clearPodLogSearch(ref);
  refreshKubernetesResources(ref);
}

final autoRefreshProvider = Provider<void>((ref) {
  final intervalSeconds = ref.watch(
    settingsProvider.select((settings) => settings.autoRefreshIntervalSeconds),
  );
  if (intervalSeconds <= 0) return;

  final timer = Timer.periodic(
    Duration(seconds: intervalSeconds),
    (_) => refreshKubernetesResources(ref),
  );

  ref.onDispose(timer.cancel);
});

class PodFilterState {
  final String searchQuery;
  final Set<String> selectedPhases;
  final bool showOnlyWithErrors;

  PodFilterState({
    this.searchQuery = '',
    this.selectedPhases = const {},
    this.showOnlyWithErrors = false,
  });

  PodFilterState copyWith({
    String? searchQuery,
    Set<String>? selectedPhases,
    bool? showOnlyWithErrors,
  }) {
    return PodFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPhases: selectedPhases ?? this.selectedPhases,
      showOnlyWithErrors: showOnlyWithErrors ?? this.showOnlyWithErrors,
    );
  }
}

class PodFilterNotifier extends StateNotifier<PodFilterState> {
  PodFilterNotifier() : super(PodFilterState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void togglePhase(String phase) {
    final phases = Set<String>.from(state.selectedPhases);
    if (phases.contains(phase)) {
      phases.remove(phase);
    } else {
      phases.add(phase);
    }
    state = state.copyWith(selectedPhases: phases);
  }

  void toggleErrorFilter() {
    state = state.copyWith(showOnlyWithErrors: !state.showOnlyWithErrors);
  }

  void reset() {
    state = PodFilterState();
  }
}

final podFilterProvider =
    StateNotifierProvider<PodFilterNotifier, PodFilterState>(
  (ref) => PodFilterNotifier(),
);

final filteredPodsProvider = Provider<AsyncValue<List<KubePod>>>((ref) {
  final podsAsync = ref.watch(currentPodsProvider);
  final filter = ref.watch(podFilterProvider);

  return podsAsync.whenData((pods) {
    var filtered = pods;
    final logSearchMatches = ref.watch(podLogSearchMatchesProvider);

    if (logSearchMatches != null) {
      filtered =
          filtered.where((pod) => logSearchMatches.contains(pod.name)).toList();
    }

    // Search filter
    if (filter.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((pod) =>
              pod.name.toLowerCase().contains(filter.searchQuery.toLowerCase()))
          .toList();
    }

    // Phase filter
    if (filter.selectedPhases.isNotEmpty) {
      filtered = filtered
          .where((pod) => filter.selectedPhases.contains(pod.phase))
          .toList();
    }

    // Error filter
    if (filter.showOnlyWithErrors) {
      filtered = filtered
          .where((pod) => pod.isFailed || pod.restartCount > 0)
          .toList();
    }

    return filtered;
  });
});

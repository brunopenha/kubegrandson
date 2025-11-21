import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/kubernetes/pod.dart';
import '../../domain/services/kubernetes_service.dart';

final kubernetesServiceProvider = Provider<KubernetesService>((ref) {
  final service = KubernetesService();
  ref.onDispose(() => service.dispose());
  return service;
});

final namespacesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(kubernetesServiceProvider);
  return service.fetchNamespaces();
});

final selectedNamespaceProvider = StateProvider<String>((ref) => 'default');

final podsProvider = FutureProvider.family<List<KubePod>, String>(
  (ref, namespace) async {
    final service = ref.watch(kubernetesServiceProvider);
    return service.fetchPods(namespace);
  },
);

final currentPodsProvider = FutureProvider<List<KubePod>>((ref) async {
  final namespace = ref.watch(selectedNamespaceProvider);
  return ref.watch(podsProvider(namespace).future);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kubegrandson/data/models/kubernetes/pod.dart';

import '../../providers/kubernetes_provider.dart';
import '../../providers/theme/app_colors.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/main_toolbar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoRefreshProvider);

    final namespacesAsync = ref.watch(namespacesProvider);
    final selectedNamespace = ref.watch(selectedNamespaceProvider);
    final selectedPodNames = ref.watch(selectedPodNamesProvider);
    final podsAsync = ref.watch(filteredPodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KubeGrandson - Kubernetes Log Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          const MainToolbar(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Namespace: '),
                const SizedBox(width: 8),
                namespacesAsync.when(
                  data: (namespaces) => DropdownButton<String>(
                    value: selectedNamespace,
                    items: namespaces
                        .map((ns) => DropdownMenuItem(
                              value: ns,
                              child: Text(ns),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedNamespaceProvider.notifier).state =
                            value;
                        ref.read(selectedPodNamesProvider.notifier).state = {};
                      }
                    },
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
                ),
              ],
            ),
          ),
          Expanded(
            child: podsAsync.when(
              data: (pods) {
                if (pods.isEmpty) {
                  return const Center(
                    child: Text('No pods found'),
                  );
                }

                return Column(
                  children: [
                    if (selectedPodNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text('${selectedPodNames.length} pod(s) selected'),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.article),
                              label: const Text('View Selected Logs'),
                              onPressed: () {
                                final selectedPods = pods
                                    .where((pod) =>
                                        selectedPodNames.contains(pod.name))
                                    .toList();
                                final namespace = selectedPods.first.namespace;
                                final query = selectedPods
                                    .map((pod) => pod.name)
                                    .map(Uri.encodeComponent)
                                    .join(',');

                                context.go(
                                  '/logs/$namespace/${selectedPods.first.name}?pods=$query',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: pods.length,
                        itemBuilder: (context, index) {
                          final pod = pods[index];
                          final selected = selectedPodNames.contains(pod.name);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (checked) {
                                      final next =
                                          Set<String>.from(selectedPodNames);
                                      if (checked ?? false) {
                                        next.add(pod.name);
                                      } else {
                                        next.remove(pod.name);
                                      }
                                      ref
                                          .read(
                                            selectedPodNamesProvider.notifier,
                                          )
                                          .state = next;
                                    },
                                  ),
                                  _buildStatusIndicator(pod.phase),
                                ],
                              ),
                              title: Text(pod.name),
                              subtitle: Text(
                                '${pod.statusText} | Restarts: ${pod.restartCount}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.article),
                                    onPressed: () {
                                      context.go(
                                        '/logs/${pod.namespace}/${pod.name}',
                                      );
                                    },
                                    tooltip: 'View Logs',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      _showDeletePodDialog(context, ref, pod);
                                    },
                                    tooltip: 'Delete Pod',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, _) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String phase) {
    Color color;
    switch (phase.toLowerCase()) {
      case 'running':
        color = AppColors.statusRunning;
        break;
      case 'pending':
        color = AppColors.statusPending;
        break;
      case 'failed':
        color = AppColors.statusFailed;
        break;
      case 'succeeded':
        color = AppColors.statusSucceeded;
        break;
      default:
        color = AppColors.statusUnknown;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

Future<void> _showDeletePodDialog(
  BuildContext context,
  WidgetRef ref,
  KubePod pod,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Delete Pod'),
        content: Text(
          'Are you sure you want to delete the pod ${pod.name} from ${pod.namespace}?',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
  if (result != true || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(kubernetesServiceProvider);
    await service.deletePod(pod.namespace, pod.name);

    final selectedPods = Set<String>.from(ref.read(selectedPodNamesProvider));
    selectedPods.remove(pod.name);
    ref.read(selectedPodNamesProvider.notifier).state = selectedPods;

    ref.invalidate(podsProvider(pod.namespace));
    ref.invalidate(currentPodsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted pod ${pod.name}')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete pod ${pod.name}: $error')),
      );
    }
  }
}

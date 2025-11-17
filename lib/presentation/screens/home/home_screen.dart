import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/kubernetes_provider.dart';
import '../../providers/theme/app_colors.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/main_toolbar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namespacesAsync = ref.watch(namespacesProvider);
    final selectedNamespace = ref.watch(selectedNamespaceProvider);
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

                return ListView.builder(
                  itemCount: pods.length,
                  itemBuilder: (context, index) {
                    final pod = pods[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: _buildStatusIndicator(pod.phase),
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
                                // TODO: Implement delete confirmation
                              },
                              tooltip: 'Delete Pod',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
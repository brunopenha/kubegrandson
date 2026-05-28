import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/kubernetes/config_map.dart';
import '../../../data/models/kubernetes/deployment.dart';
import '../../../data/models/kubernetes/pod.dart';
import '../../providers/kubernetes_provider.dart';

class ConfigMapScreen extends ConsumerStatefulWidget {
  final String namespace;
  final String groupName;
  final List<String> podNames;

  const ConfigMapScreen({
    super.key,
    required this.namespace,
    required this.groupName,
    required this.podNames,
  });

  @override
  ConsumerState<ConfigMapScreen> createState() => _ConfigMapScreenState();
}

class _ConfigMapScreenState extends ConsumerState<ConfigMapScreen> {
  final TextEditingController _configMapController = TextEditingController();
  final TextEditingController _deploymentController = TextEditingController();
  String? _selectedConfigMapName;
  String? _selectedDeploymentName;
  bool _deploymentSpecLoading = false;

  @override
  void dispose() {
    _configMapController.dispose();
    _deploymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final podsAsync = ref.watch(podsProvider(widget.namespace));
    final configMapsAsync = ref.watch(configMapsProvider(widget.namespace));
    final deploymentsAsync = ref.watch(deploymentsProvider(widget.namespace));

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuration: ${widget.groupName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart Pods',
            onPressed: () => _restartRelatedPods(),
          ),
        ],
      ),
      body: podsAsync.when(
        data: (pods) {
          final relatedPods = pods
              .where((pod) => widget.podNames.contains(pod.name))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return configMapsAsync.when(
            data: (configMaps) {
              return deploymentsAsync.when(
                data: (deployments) {
                  final relatedConfigMaps = _relatedByLabels(
                    configMaps,
                    relatedPods,
                    (configMap) => configMap.labels,
                  );
                  final relatedDeployments = _relatedByLabels(
                    deployments,
                    relatedPods,
                    (deployment) => deployment.labels,
                  );

                  if (relatedConfigMaps.isNotEmpty) {
                    _selectedConfigMapName ??= relatedConfigMaps.first.name;
                  }
                  if (relatedDeployments.isNotEmpty) {
                    _selectedDeploymentName ??= relatedDeployments.first.name;
                  }

                  final selectedConfigMap = _firstWhereOrNull(
                    relatedConfigMaps,
                    (cm) => cm.name == _selectedConfigMapName,
                  );
                  final selectedDeployment = _firstWhereOrNull(
                    relatedDeployments,
                    (deployment) => deployment.name == _selectedDeploymentName,
                  );

                  if (selectedConfigMap != null &&
                      _configMapController.text.isEmpty) {
                    _configMapController.text =
                        _formatJson(selectedConfigMap.data ?? {});
                  }
                  if (selectedDeployment != null &&
                      _deploymentController.text.isEmpty &&
                      !_deploymentSpecLoading) {
                    _loadDeploymentSpec(selectedDeployment);
                  }

                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: const TabBar(
                            tabs: [
                              Tab(text: 'ConfigMap'),
                              Tab(text: 'Deployment'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildConfigMapEditor(
                                selectedConfigMap,
                                relatedConfigMaps,
                              ),
                              _buildDeploymentEditor(
                                selectedDeployment,
                                relatedDeployments,
                              ),
                            ],
                          ),
                        ),
                        _buildFooter(
                          relatedPods.length,
                          selectedConfigMap,
                          selectedDeployment,
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildConfigMapEditor(
    KubeConfigMap? selected,
    List<KubeConfigMap> configMaps,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected?.name,
            decoration: const InputDecoration(
              labelText: 'ConfigMap',
              border: OutlineInputBorder(),
            ),
            items: configMaps
                .map((cm) =>
                    DropdownMenuItem(value: cm.name, child: Text(cm.name)))
                .toList(),
            onChanged: (value) {
              final next = _firstWhereOrNull(
                configMaps,
                (cm) => cm.name == value,
              );
              setState(() {
                _selectedConfigMapName = value;
                _configMapController.text = _formatJson(next?.data ?? {});
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _JsonEditor(
              controller: _configMapController,
              label: 'ConfigMap data as JSON',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentEditor(
    KubeDeployment? selected,
    List<KubeDeployment> deployments,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected?.name,
            decoration: const InputDecoration(
              labelText: 'Deployment',
              border: OutlineInputBorder(),
            ),
            items: deployments
                .map(
                  (deployment) => DropdownMenuItem(
                    value: deployment.name,
                    child: Text(deployment.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final next = _firstWhereOrNull(
                deployments,
                (deployment) => deployment.name == value,
              );
              setState(() {
                _selectedDeploymentName = value;
                _deploymentController.clear();
              });
              if (next != null) {
                _loadDeploymentSpec(next);
              }
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _deploymentSpecLoading
                ? const Center(child: CircularProgressIndicator())
                : _JsonEditor(
                    controller: _deploymentController,
                    label: 'Deployment spec as JSON',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    int relatedPodCount,
    KubeConfigMap? selectedConfigMap,
    KubeDeployment? selectedDeployment,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Text('$relatedPodCount pod(s) will restart together'),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save ConfigMap'),
            style: _actionButtonStyle(_ActionTone.neutral),
            onPressed: selectedConfigMap == null
                ? null
                : () => _saveConfigMap(selectedConfigMap),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.save_as),
            label: const Text('Save Deployment'),
            style: _actionButtonStyle(_ActionTone.primary),
            onPressed: selectedDeployment == null
                ? null
                : () => _saveDeployment(selectedDeployment),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart Pods'),
            style: _actionButtonStyle(_ActionTone.warning),
            onPressed:
                relatedPodCount == 0 ? null : () => _restartRelatedPods(),
          ),
        ],
      ),
    );
  }

  ButtonStyle _actionButtonStyle(_ActionTone tone) {
    final colors = switch (tone) {
      _ActionTone.neutral => (
          enabledBg: const Color(0xFF5F6770),
          enabledFg: Colors.white,
          disabledBg: const Color(0xFFCFD3D8),
          disabledFg: const Color(0xFF5E646B),
        ),
      _ActionTone.primary => (
          enabledBg: const Color(0xFF5A8FD8),
          enabledFg: Colors.white,
          disabledBg: const Color(0xFFCFD9E8),
          disabledFg: const Color(0xFF5F6F86),
        ),
      _ActionTone.warning => (
          enabledBg: const Color(0xFFB88445),
          enabledFg: Colors.white,
          disabledBg: const Color(0xFFE3D4C0),
          disabledFg: const Color(0xFF76624A),
        ),
    };

    return FilledButton.styleFrom(
      backgroundColor: colors.enabledBg,
      foregroundColor: colors.enabledFg,
      disabledBackgroundColor: colors.disabledBg,
      disabledForegroundColor: colors.disabledFg,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
  }

  List<T> _relatedByLabels<T>(
    List<T> resources,
    List<KubePod> pods,
    Map<String, String>? Function(T resource) labelsOf,
  ) {
    final podLabels = pods.expand((pod) => (pod.labels ?? {}).entries).toList();
    if (podLabels.isEmpty) return resources;

    return resources.where((resource) {
      final labels = labelsOf(resource) ?? const <String, String>{};
      return podLabels.any((label) => labels[label.key] == label.value);
    }).toList()
      ..sort((a, b) {
        final left = (a as dynamic).name as String;
        final right = (b as dynamic).name as String;
        return left.compareTo(right);
      });
  }

  String _formatJson(Object data) {
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> _loadDeploymentSpec(KubeDeployment deployment) async {
    setState(() => _deploymentSpecLoading = true);
    try {
      final spec = await ref.read(kubernetesServiceProvider).readDeploymentSpec(
            namespace: deployment.namespace,
            name: deployment.name,
          );
      if (!mounted) return;
      setState(() {
        _deploymentController.text = _formatJson(spec);
        _deploymentSpecLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _deploymentSpecLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Deployment: $error')),
      );
    }
  }

  Future<void> _saveConfigMap(KubeConfigMap configMap) async {
    try {
      final decoded = jsonDecode(_configMapController.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }

      final data = decoded.map((key, value) {
        return MapEntry(key, value?.toString() ?? '');
      });

      await ref.read(kubernetesServiceProvider).updateConfigMapData(
            namespace: configMap.namespace,
            name: configMap.name,
            data: data,
          );
      ref.invalidate(configMapsProvider(widget.namespace));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ConfigMap ${configMap.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ConfigMap: $error')),
      );
    }
  }

  Future<void> _saveDeployment(KubeDeployment deployment) async {
    try {
      final decoded = jsonDecode(_deploymentController.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }

      await ref.read(kubernetesServiceProvider).updateDeploymentSpec(
            namespace: deployment.namespace,
            name: deployment.name,
            spec: decoded,
          );
      ref.invalidate(deploymentsProvider(widget.namespace));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved Deployment ${deployment.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save Deployment: $error')),
      );
    }
  }

  Future<void> _restartRelatedPods() async {
    final pods = await ref.read(podsProvider(widget.namespace).future);
    final relatedPods = pods
        .where((pod) => widget.podNames.contains(pod.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (relatedPods.isEmpty) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Pods'),
        content: Text(
          'Delete ${relatedPods.length} pod(s) from ${widget.namespace}? '
          'The owning Deployment should recreate them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(kubernetesServiceProvider);
      for (final pod in relatedPods) {
        await service.deletePod(pod.namespace, pod.name);
      }
      ref.invalidate(podsProvider(widget.namespace));
      ref.invalidate(currentPodsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restarted ${relatedPods.length} pod(s)')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restart pods: $error')),
      );
    }
  }
}

class _JsonEditor extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _JsonEditor({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'RobotoMono'),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

enum _ActionTone { neutral, primary, warning }

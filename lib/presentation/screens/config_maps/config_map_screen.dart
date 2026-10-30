import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yaml/yaml.dart';
import '../../../core/utils/yaml_formatter.dart';

import '../../../data/models/kubernetes/config_map.dart';
import '../../../data/models/kubernetes/deployment.dart';
import '../../../data/models/kubernetes/pod.dart';
import '../../providers/kubernetes_provider.dart';

class ConfigMapScreen extends ConsumerStatefulWidget {
  final bool editDeployment;
  final String namespace;
  final String groupName;
  final List<String> podNames;

  const ConfigMapScreen({
    super.key,
    this.editDeployment = false,
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
  String? _loadedConfigMapName;
  String? _loadedDeploymentName;

  @override
  void dispose() {
    _configMapController.dispose();
    _deploymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final podsAsync = ref.watch(podsProvider(widget.namespace));
    final configMapsAsync = widget.editDeployment
        ? const AsyncData<List<KubeConfigMap>>([])
        : ref.watch(configMapsProvider(widget.namespace));
    final deploymentsAsync = widget.editDeployment
        ? ref.watch(deploymentsProvider(widget.namespace))
        : const AsyncData<List<KubeDeployment>>([]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.editDeployment ? 'Deployment' : 'ConfigMap'}: ${widget.groupName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
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
                    (deployment) => deployment.selectorLabels,
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
                      _loadedConfigMapName != selectedConfigMap.name) {
                    _loadedConfigMapName = selectedConfigMap.name;
                    _configMapController.text =
                        formatYaml(selectedConfigMap.data ?? {});
                  }
                  if (selectedDeployment != null &&
                      _loadedDeploymentName != selectedDeployment.name &&
                      !_deploymentSpecLoading) {
                    _loadDeploymentSpec(selectedDeployment);
                  }

                  return widget.editDeployment
                      ? _buildDeploymentEditor(selectedDeployment,
                          relatedDeployments, relatedPods.length)
                      : _buildConfigMapEditor(selectedConfigMap,
                          relatedConfigMaps, relatedPods.length);
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
    int relatedPodCount,
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
                _configMapController.text = formatYaml(next?.data ?? {});
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _YamlEditor(
              controller: _configMapController,
              label: 'ConfigMap data as YAML',
              actions: _buildActions(relatedPodCount, selected, null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentEditor(
    KubeDeployment? selected,
    List<KubeDeployment> deployments,
    int relatedPodCount,
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
                : _YamlEditor(
                    controller: _deploymentController,
                    label: 'Deployment spec as YAML',
                    actions: _buildActions(relatedPodCount, null, selected),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    int relatedPodCount,
    KubeConfigMap? selectedConfigMap,
    KubeDeployment? selectedDeployment,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!widget.editDeployment)
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save ConfigMap'),
            style: _actionButtonStyle(_ActionTone.neutral),
            onPressed: selectedConfigMap == null
                ? null
                : () => _saveConfigMap(selectedConfigMap),
          ),
        if (widget.editDeployment)
          FilledButton.icon(
            icon: const Icon(Icons.save_as),
            label: const Text('Save Deployment'),
            style: _actionButtonStyle(_ActionTone.primary),
            onPressed: selectedDeployment == null
                ? null
                : () => _saveDeployment(selectedDeployment),
          ),
        Tooltip(
            message: '$relatedPodCount pod(s) will restart together',
            child: FilledButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart Pods'),
              style: _actionButtonStyle(_ActionTone.warning),
              onPressed:
                  relatedPodCount == 0 ? null : () => _restartRelatedPods(),
            )),
      ],
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

  Object? _parseYaml(String content) {
    return _toPlainYamlValue(loadYaml(content));
  }

  Object? _toPlainYamlValue(Object? value) {
    if (value is YamlMap) {
      return value.map((key, nestedValue) {
        return MapEntry(key.toString(), _toPlainYamlValue(nestedValue));
      });
    }
    if (value is YamlList) {
      return value.map(_toPlainYamlValue).toList();
    }
    return value;
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> _loadDeploymentSpec(KubeDeployment deployment) async {
    _loadedDeploymentName = deployment.name;
    _deploymentSpecLoading = true;
    try {
      final spec = await ref.read(kubernetesServiceProvider).readDeploymentSpec(
            namespace: deployment.namespace,
            name: deployment.name,
          );
      if (!mounted || _selectedDeploymentName != deployment.name) return;
      setState(() {
        _deploymentController.text = formatYaml(spec);
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
      final decoded = _parseYaml(_configMapController.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a YAML object');
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
      final decoded = _parseYaml(_deploymentController.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a YAML object');
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
      final restartedPodNames = relatedPods.map((pod) => pod.name).toSet();
      final selectedPodNames =
          Set<String>.from(ref.read(selectedPodNamesProvider))
            ..removeAll(restartedPodNames);
      ref.read(selectedPodNamesProvider.notifier).state = selectedPodNames;
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

class _YamlEditor extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget actions;

  const _YamlEditor({
    required this.controller,
    required this.label,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              Text(label),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Format YAML',
                  icon: const Icon(Icons.format_align_left),
                  onPressed: () => _checkYaml(context, format: true),
                ),
                IconButton(
                  tooltip: 'Validate YAML',
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _checkYaml(context),
                ),
              ]),
              actions,
            ]),
        const SizedBox(height: 8),
        Expanded(
            child: TextField(
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
        )),
      ],
    );
  }

  void _checkYaml(BuildContext context, {bool format = false}) {
    try {
      final value = loadYaml(controller.text);
      if (value is! YamlMap) {
        throw const FormatException('Expected a YAML object');
      }
      if (format) controller.text = formatYaml(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(format ? 'YAML formatted' : 'Valid YAML')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid YAML: $error')),
      );
    }
  }
}

enum _ActionTone { neutral, primary, warning }

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:kubegrandson/core/utils/error_utils.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/data/models/kubernetes/pod.dart';
import 'package:kubegrandson/presentation/widgets/common/cluster_offline.dart';

import '../../providers/kubernetes_provider.dart';
import '../../providers/theme/app_colors.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/main_toolbar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoRefreshProvider);

    final contextsAsync = ref.watch(contextsProvider);
    final namespacesAsync = ref.watch(namespacesProvider);
    final selectedNamespace = ref.watch(selectedNamespaceProvider);
    final selectedPodNames = ref.watch(selectedPodNamesProvider);
    final podsAsync = ref.watch(filteredPodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KubeGrandson - Kubernetes Log Viewer'),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/aws_mark.svg',
              width: 24,
              height: 24,
            ),
            tooltip: 'AWS Credentials',
            onPressed: () => _promptAwsSsoRefresh(context, ref),
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/gcp_mark.svg',
              width: 24,
              height: 24,
            ),
            tooltip: 'GCP Credentials',
            onPressed: () => _promptGcpCredentialsRefresh(context, ref),
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Context: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: contextsAsync.when(
                        data: (contexts) {
                          if (contexts.isEmpty) {
                            return const Text('No contexts found');
                          }

                          final activeContext = contexts.firstWhere(
                            (ctx) => ctx.isActive,
                            orElse: () => contexts.first,
                          );

                          return DropdownButton<String>(
                            isExpanded: true,
                            value: activeContext.name,
                            items: contexts
                                .map((ctx) => DropdownMenuItem(
                                      value: ctx.name,
                                      child: Text(
                                        ctx.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              if (value == null ||
                                  value == activeContext.name) {
                                return;
                              }

                              final selectedContext = contexts.firstWhere(
                                (ctx) => ctx.name == value,
                                orElse: () => activeContext,
                              );

                              try {
                                await switchKubernetesContext(
                                  ref,
                                  contextName: value,
                                  namespace: selectedContext.namespace,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Switched context to $value'),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to switch context: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                        loading: () => const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => Row(
                          children: const [
                            Icon(
                              Icons.cloud_off,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cluster offline',
                              style: TextStyle(color: AppColors.warning),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Namespace: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: namespacesAsync.when(
                        data: (namespaces) {
                          if (namespaces.isEmpty) {
                            return const Text('No namespaces found');
                          }

                          final effectiveNamespace =
                              namespaces.contains(selectedNamespace)
                                  ? selectedNamespace
                                  : namespaces.first;

                          if (effectiveNamespace != selectedNamespace) {
                            Future.microtask(() {
                              ref
                                  .read(selectedNamespaceProvider.notifier)
                                  .state = effectiveNamespace;
                              ref
                                  .read(selectedPodNamesProvider.notifier)
                                  .state = {};
                            });
                          }

                          return DropdownButton<String>(
                            isExpanded: true,
                            value: effectiveNamespace,
                            items: namespaces
                                .map((ns) => DropdownMenuItem(
                                      value: ns,
                                      child: Text(ns),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(selectedNamespaceProvider.notifier)
                                    .state = value;
                                ref
                                    .read(selectedPodNamesProvider.notifier)
                                    .state = {};
                              }
                            },
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, _) => Row(
                          children: const [
                            Icon(
                              Icons.cloud_off,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            SizedBox(
                              width: 6,
                            ),
                            Text(
                              'Cluster offline',
                              style: TextStyle(color: AppColors.warning),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Open JSON Log'),
                  onPressed: () => _openJsonLogFile(context),
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

                  final podGroups = groupPodsByLabel(pods);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            if (selectedPodNames.isNotEmpty)
                              Text(
                                  '${selectedPodNames.length} pod(s) selected'),
                            const Spacer(),
                            if (selectedPodNames.isNotEmpty) ...[
                              OutlinedButton.icon(
                                icon: const Icon(Icons.article),
                                label: const Text('View Selected Logs'),
                                onPressed: () {
                                  final selectedPods = pods
                                      .where((pod) =>
                                          selectedPodNames.contains(pod.name))
                                      .toList();
                                  final namespace =
                                      selectedPods.first.namespace;
                                  final query = selectedPods
                                      .map((pod) => pod.name)
                                      .map(Uri.encodeComponent)
                                      .join(',');
                                  final title =
                                      logViewerTitleForPods(selectedPods);

                                  context.go(
                                    '/logs/$namespace/${Uri.encodeComponent(title)}?pods=$query',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: podGroups.length,
                          itemBuilder: (context, index) {
                            final group = podGroups[index];
                            final selected = group.pods.every(
                                (pod) => selectedPodNames.contains(pod.name));
                            final partiallySelected = !selected &&
                                group.pods.any((pod) =>
                                    selectedPodNames.contains(pod.name));

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
                                      tristate: true,
                                      value:
                                          partiallySelected ? null : selected,
                                      onChanged: (checked) {
                                        final next =
                                            Set<String>.from(selectedPodNames);
                                        if (checked ?? false) {
                                          next.addAll(group.pods
                                              .map((pod) => pod.name));
                                        } else {
                                          next.removeAll(group.pods
                                              .map((pod) => pod.name));
                                        }
                                        ref
                                            .read(
                                              selectedPodNamesProvider.notifier,
                                            )
                                            .state = next;
                                      },
                                    ),
                                    _buildStatusIndicator(group.phase),
                                  ],
                                ),
                                title: Text(group.title),
                                subtitle: Text(
                                  '${group.pods.length} replica(s) | ${group.statusText} | Restarts: ${group.restartCount}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.article),
                                      onPressed: () {
                                        final query = group.pods
                                            .map((pod) => pod.name)
                                            .map(Uri.encodeComponent)
                                            .join(',');
                                        context.go(
                                          '/logs/${group.namespace}/${Uri.encodeComponent(group.title)}?pods=$query',
                                        );
                                      },
                                      tooltip: 'View Logs',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.settings_applications),
                                      onPressed: () {
                                        final query = group.pods
                                            .map((pod) => pod.name)
                                            .map(Uri.encodeComponent)
                                            .join(',');
                                        context.go(
                                          '/configmaps/${group.namespace}/${Uri.encodeComponent(group.title)}?pods=$query',
                                        );
                                      },
                                      tooltip: 'ConfigMaps',
                                    ),
                                    if (group.pods.length == 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          _showDeletePodDialog(
                                            context,
                                            ref,
                                            group.pods.single,
                                          );
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
                error: (error, _) {
                  if (isAwsUnauthorizedError(error)) {
                    return _AwsUnauthorized(
                      errorMessage: error.toString(),
                      onRefreshCredentials: () =>
                          _promptAwsSsoRefresh(context, ref),
                    );
                  }

                  if (isClusterOfflineError(error)) {
                    return ClusterOffline(
                      onRetry: () {
                        ref.invalidate(initializeProvider);
                        refreshKubernetesResources(ref);
                      },
                    );
                  }

                  return Center(
                    child: Text('Error: $error'),
                  );
                }),
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

  Future<void> _openJsonLogFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open JSON log file',
      type: FileType.custom,
      allowedExtensions: const ['json', 'jsonl', 'ndjson', 'log'],
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final fileName = result?.files.single.name ?? 'imported-json-log';
    context.go(
      '/logs/local/${Uri.encodeComponent(fileName)}'
      '?importPath=${Uri.encodeComponent(path)}',
    );
  }
}

@visibleForTesting
String logViewerTitleForPods(List<KubePod> pods) {
  if (pods.length == 1) return pods.single.name;

  return groupPodsByLabel(pods).map((group) => group.title).join(', ');
}

Future<void> _promptAwsSsoRefresh(BuildContext context, WidgetRef ref) async {
  final service = ref.read(kubernetesServiceProvider);
  final storage = await LocalStorageClient.getInstance();
  final info = service.currentAwsEksContextInfo;
  final defaultProfile = (await storage.getAwsProfile()) ??
      (await service.getCurrentAwsProfile()) ??
      '';
  final defaultRegion = (await storage.getAwsRegion()) ?? info?.region ?? '';
  final defaultCluster =
      (await storage.getAwsClusterName()) ?? info?.clusterName ?? '';
  final defaultAccount =
      (await storage.getAwsAccountId()) ?? info?.accountId ?? '';
  final defaultSsoStartUrl = (await storage.getAwsSsoStartUrl()) ?? '';
  final defaultSsoRegion = (await storage.getAwsSsoRegion()) ?? defaultRegion;

  if (!context.mounted) {
    return;
  }

  final values = await showDialog<_AwsCredentialsInput>(
    context: context,
    builder: (dialogContext) {
      return _AwsCredentialsDialog(
        initial: _AwsCredentialsInput(
          profile: defaultProfile,
          region: defaultRegion,
          clusterName: defaultCluster,
          accountId: defaultAccount,
          ssoStartUrl: defaultSsoStartUrl,
          ssoRegion: defaultSsoRegion,
        ),
        contextName: info?.contextName,
      );
    },
  );

  if (values == null || !context.mounted) {
    return;
  }
  if (values.profile.isEmpty ||
      values.region.isEmpty ||
      values.clusterName.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile, region, and cluster name are required.'),
        ),
      );
    }
    return;
  }

  try {
    await service.refreshAwsSsoCredentials(
      profile: values.profile,
      region: values.region,
      clusterName: values.clusterName,
      accountId: values.accountId.isEmpty ? null : values.accountId,
    );
    await storage.setAwsProfile(values.profile);
    await storage.setAwsRegion(values.region);
    await storage.setAwsClusterName(values.clusterName);
    await storage.setAwsAccountId(values.accountId);
    await storage.setAwsSsoStartUrl(values.ssoStartUrl);
    await storage.setAwsSsoRegion(values.ssoRegion);

    ref.invalidate(initializeProvider);
    refreshKubernetesResources(ref);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AWS credentials refreshed with profile "${values.profile}".',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AWS credential refresh failed: $e'),
        ),
      );
    }
  }
}

Future<void> _promptGcpCredentialsRefresh(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(kubernetesServiceProvider);
  final storage = await LocalStorageClient.getInstance();
  final info = service.currentGcpGkeContextInfo;
  String? inferredAccount;
  try {
    inferredAccount = await service.getCurrentGcpAccount();
  } catch (_) {
    inferredAccount = null;
  }
  String? inferredProjectId;
  try {
    inferredProjectId = await service.getCurrentGcpProjectId();
  } catch (_) {
    inferredProjectId = null;
  }

  final defaultProjectId = (await storage.getGcpProjectId()) ??
      info?.projectId ??
      inferredProjectId ??
      '';
  final defaultLocation =
      (await storage.getGcpLocation()) ?? info?.location ?? '';
  final defaultLocationType = (await storage.getGcpLocationType()) ??
      service.getCurrentGcpLocationType() ??
      'zone';
  final defaultCluster =
      (await storage.getGcpClusterName()) ?? info?.clusterName ?? '';
  final defaultAccount =
      (await storage.getGcpAccount()) ?? inferredAccount ?? '';

  if (!context.mounted) {
    return;
  }

  final values = await showDialog<_GcpCredentialsInput>(
    context: context,
    builder: (dialogContext) {
      return _GcpCredentialsDialog(
        initial: _GcpCredentialsInput(
          projectId: defaultProjectId,
          location: defaultLocation,
          locationType: defaultLocationType,
          clusterName: defaultCluster,
          account: defaultAccount,
        ),
        contextName: info?.contextName,
      );
    },
  );

  if (values == null || !context.mounted) {
    return;
  }
  if (values.projectId.isEmpty ||
      values.location.isEmpty ||
      values.clusterName.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Project ID, location, and cluster name are required.'),
      ),
    );
    return;
  }

  try {
    await service.refreshGcpCredentials(
      projectId: values.projectId,
      location: values.location,
      locationType: values.locationType,
      clusterName: values.clusterName,
      account: values.account.isEmpty ? null : values.account,
    );
    await storage.setGcpProjectId(values.projectId);
    await storage.setGcpLocation(values.location);
    await storage.setGcpLocationType(values.locationType);
    await storage.setGcpClusterName(values.clusterName);
    await storage.setGcpAccount(values.account);

    ref.invalidate(initializeProvider);
    refreshKubernetesResources(ref);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GCP credentials refreshed for "${values.clusterName}".',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GCP credential refresh failed: $e'),
        ),
      );
    }
  }
}

class _AwsCredentialsInput {
  final String profile;
  final String region;
  final String clusterName;
  final String accountId;
  final String ssoStartUrl;
  final String ssoRegion;

  const _AwsCredentialsInput({
    required this.profile,
    required this.region,
    required this.clusterName,
    required this.accountId,
    required this.ssoStartUrl,
    required this.ssoRegion,
  });
}

class _AwsCredentialsDialog extends StatefulWidget {
  final _AwsCredentialsInput initial;
  final String? contextName;

  const _AwsCredentialsDialog({
    required this.initial,
    this.contextName,
  });

  @override
  State<_AwsCredentialsDialog> createState() => _AwsCredentialsDialogState();
}

class _AwsCredentialsDialogState extends State<_AwsCredentialsDialog> {
  late final TextEditingController _profileController;
  late final TextEditingController _regionController;
  late final TextEditingController _clusterController;
  late final TextEditingController _accountController;
  late final TextEditingController _ssoStartUrlController;
  late final TextEditingController _ssoRegionController;

  @override
  void initState() {
    super.initState();
    _profileController = TextEditingController(text: widget.initial.profile);
    _regionController = TextEditingController(text: widget.initial.region);
    _clusterController =
        TextEditingController(text: widget.initial.clusterName);
    _accountController = TextEditingController(text: widget.initial.accountId);
    _ssoStartUrlController =
        TextEditingController(text: widget.initial.ssoStartUrl);
    _ssoRegionController =
        TextEditingController(text: widget.initial.ssoRegion);
  }

  @override
  void dispose() {
    _profileController.dispose();
    _regionController.dispose();
    _clusterController.dispose();
    _accountController.dispose();
    _ssoStartUrlController.dispose();
    _ssoRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AWS Credentials'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.contextName != null && widget.contextName!.isNotEmpty)
                Text('Current context: ${widget.contextName}'),
              const SizedBox(height: 12),
              TextField(
                controller: _profileController,
                decoration: const InputDecoration(
                  labelText: 'AWS Profile *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _regionController,
                decoration: const InputDecoration(
                  labelText: 'AWS Region *',
                  hintText: 'your-region',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clusterController,
                decoration: const InputDecoration(
                  labelText: 'EKS Cluster Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'AWS Account ID (Optional)',
                  hintText: 'your-12-digit-account-id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ssoStartUrlController,
                decoration: const InputDecoration(
                  labelText: 'SSO Start URL (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ssoRegionController,
                decoration: const InputDecoration(
                  labelText: 'SSO Region (Optional)',
                  hintText: 'your-sso-region',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              _AwsCredentialsInput(
                profile: _profileController.text.trim(),
                region: _regionController.text.trim(),
                clusterName: _clusterController.text.trim(),
                accountId: _accountController.text.trim(),
                ssoStartUrl: _ssoStartUrlController.text.trim(),
                ssoRegion: _ssoRegionController.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.login),
          label: const Text('SSO Login & Update'),
        ),
      ],
    );
  }
}

class _GcpCredentialsInput {
  final String projectId;
  final String location;
  final String locationType;
  final String clusterName;
  final String account;

  const _GcpCredentialsInput({
    required this.projectId,
    required this.location,
    required this.locationType,
    required this.clusterName,
    required this.account,
  });
}

class _GcpCredentialsDialog extends StatefulWidget {
  final _GcpCredentialsInput initial;
  final String? contextName;

  const _GcpCredentialsDialog({
    required this.initial,
    this.contextName,
  });

  @override
  State<_GcpCredentialsDialog> createState() => _GcpCredentialsDialogState();
}

class _GcpCredentialsDialogState extends State<_GcpCredentialsDialog> {
  late final TextEditingController _projectController;
  late final TextEditingController _locationController;
  late final TextEditingController _clusterController;
  late final TextEditingController _accountController;
  late String _locationType;

  @override
  void initState() {
    super.initState();
    _projectController = TextEditingController(text: widget.initial.projectId);
    _locationController = TextEditingController(text: widget.initial.location);
    _clusterController =
        TextEditingController(text: widget.initial.clusterName);
    _accountController = TextEditingController(text: widget.initial.account);
    _locationType = widget.initial.locationType == 'region' ? 'region' : 'zone';
  }

  @override
  void dispose() {
    _projectController.dispose();
    _locationController.dispose();
    _clusterController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GCP Credentials'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.contextName != null && widget.contextName!.isNotEmpty)
                Text('Current context: ${widget.contextName}'),
              const SizedBox(height: 12),
              TextField(
                controller: _projectController,
                decoration: const InputDecoration(
                  labelText: 'GCP Project ID *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'GKE Location *',
                  hintText: 'region-or-zone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Location Type *',
                  border: OutlineInputBorder(),
                ),
                initialValue: _locationType,
                items: const [
                  DropdownMenuItem(
                    value: 'zone',
                    child: Text('Zone'),
                  ),
                  DropdownMenuItem(
                    value: 'region',
                    child: Text('Region'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _locationType = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clusterController,
                decoration: const InputDecoration(
                  labelText: 'GKE Cluster Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'GCP Account (Optional)',
                  hintText: 'you@example.com',
                  border: OutlineInputBorder(),
                  helperText:
                      'When filled, gcloud auth login runs before updating kubeconfig.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              _GcpCredentialsInput(
                projectId: _projectController.text.trim(),
                location: _locationController.text.trim(),
                locationType: _locationType,
                clusterName: _clusterController.text.trim(),
                account: _accountController.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.login),
          label: const Text('Login & Update'),
        ),
      ],
    );
  }
}

class _AwsUnauthorized extends StatelessWidget {
  final String errorMessage;
  final Future<void> Function() onRefreshCredentials;

  const _AwsUnauthorized({
    required this.errorMessage,
    required this.onRefreshCredentials,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_open,
              color: AppColors.warning,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'AWS Session Expired',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use AWS SSO login to refresh credentials for the current EKS context.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                onRefreshCredentials();
              },
              icon: const Icon(Icons.login),
              label: const Text('Refresh AWS Credentials'),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PodGroup {
  final String title;
  final String namespace;
  final String phase;
  final List<KubePod> pods;

  const PodGroup({
    required this.title,
    required this.namespace,
    required this.phase,
    required this.pods,
  });

  int get restartCount => pods.fold(0, (sum, pod) => sum + pod.restartCount);

  String get statusText {
    final readyPods = pods.where((pod) => pod.isRunning).length;
    return '$readyPods/${pods.length} Running';
  }
}

@visibleForTesting
List<PodGroup> groupPodsByLabel(List<KubePod> pods) {
  final groups = <String, List<KubePod>>{};

  for (final pod in pods) {
    final groupName = _podGroupName(pod);
    final key = '${pod.namespace}/$groupName';
    groups.putIfAbsent(key, () => []).add(pod);
  }

  final podGroups = groups.entries.map((entry) {
    final groupPods = [...entry.value]
      ..sort((a, b) => a.name.compareTo(b.name));
    final first = groupPods.first;

    return PodGroup(
      title: _podGroupName(first),
      namespace: first.namespace,
      phase: _groupPhase(groupPods),
      pods: groupPods,
    );
  }).toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  return podGroups;
}

String _podGroupName(KubePod pod) {
  final labels = pod.labels ?? const <String, String>{};

  return labels['app.kubernetes.io/name'] ??
      labels['app'] ??
      labels['k8s-app'] ??
      labels['component'] ??
      _replicaSetPrefix(pod.name);
}

String _replicaSetPrefix(String podName) {
  final parts = podName.split('-');
  if (parts.length >= 3) {
    return parts.take(parts.length - 2).join('-');
  }

  return podName;
}

String _groupPhase(List<KubePod> pods) {
  if (pods.any((pod) => pod.isFailed)) return 'Failed';
  if (pods.any((pod) => pod.isPending)) return 'Pending';
  if (pods.every((pod) => pod.isRunning)) return 'Running';
  if (pods.every((pod) => pod.isSucceeded)) return 'Succeeded';
  return 'Unknown';
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

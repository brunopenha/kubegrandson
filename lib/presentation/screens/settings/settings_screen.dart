import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../data/datasources/local_storage_client.dart';
import '../../providers/kubernetes_provider.dart';
import '../../providers/settings_notifier.dart';
import '../../providers/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../shortcuts/log_navigation_shortcuts.dart';
import '../../theme/app_text_styles.dart';

enum _ShortcutAction {
  lineUp('lineUp', 'Go line up'),
  lineDown('lineDown', 'Go line down');

  final String id;
  final String label;

  const _ShortcutAction(this.id, this.label);

  static _ShortcutAction? fromId(String? id) {
    for (final action in values) {
      if (action.id == id) return action;
    }

    return null;
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _kubeconfigController = TextEditingController();
  final TextEditingController _awsProfileController = TextEditingController();
  final TextEditingController _awsRegionController = TextEditingController();
  final TextEditingController _awsClusterController = TextEditingController();
  final TextEditingController _awsAccountIdController = TextEditingController();
  final TextEditingController _awsSsoStartUrlController =
      TextEditingController();
  final TextEditingController _awsSsoRegionController = TextEditingController();
  final FocusNode _shortcutCaptureFocusNode = FocusNode();
  String? _capturingShortcutAction;

  // ignore: unused_field
  bool _isAwsRefreshing = false;

  final Uri toLaunch = Uri(
    scheme: 'https',
    host: 'github.com',
    path: 'brunopenha/kubegrandson/releases',
  );

  @override
  void initState() {
    super.initState();
    _loadStoredConfiguration();
  }

  @override
  void dispose() {
    _kubeconfigController.dispose();
    _awsProfileController.dispose();
    _awsRegionController.dispose();
    _awsClusterController.dispose();
    _awsAccountIdController.dispose();
    _awsSsoStartUrlController.dispose();
    _awsSsoRegionController.dispose();
    _shortcutCaptureFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStoredConfiguration() async {
    final storage = await LocalStorageClient.getInstance();
    final service = ref.read(kubernetesServiceProvider);
    final awsContextInfo = service.currentAwsEksContextInfo;

    String? inferredProfile;
    try {
      inferredProfile = await service.getCurrentAwsProfile();
    } catch (_) {
      inferredProfile = null;
    }

    final kubeconfigPath = await storage.getKubeConfigPath();
    final awsProfile = await storage.getAwsProfile();
    final awsRegion = await storage.getAwsRegion();
    final awsCluster = await storage.getAwsClusterName();
    final awsAccountId = await storage.getAwsAccountId();
    final awsSsoStartUrl = await storage.getAwsSsoStartUrl();
    final awsSsoRegion = await storage.getAwsSsoRegion();

    if (!mounted) {
      return;
    }

    _kubeconfigController.text = kubeconfigPath ?? '';
    _awsProfileController.text = awsProfile ?? inferredProfile ?? '';
    _awsRegionController.text = awsRegion ?? awsContextInfo?.region ?? '';
    _awsClusterController.text =
        awsCluster ?? awsContextInfo?.clusterName ?? '';
    _awsAccountIdController.text =
        awsAccountId ?? awsContextInfo?.accountId ?? '';
    _awsSsoStartUrlController.text = awsSsoStartUrl ?? '';
    _awsSsoRegionController.text = awsSsoRegion ?? _awsRegionController.text;
  }

  Future<void> _pickKubeconfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select Kubeconfig File',
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final path = result.files.single.path!;
    _kubeconfigController.text = path;

    try {
      await ref.read(kubernetesServiceProvider).initialize(
            kubeconfigPath: path,
            verifyConnection: false,
          );
      final storage = await LocalStorageClient.getInstance();
      await storage.setKubeConfigPath(path);
      ref.invalidate(initializeProvider);
      refreshKubernetesResources(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kubeconfig loaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load kubeconfig: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveAwsSettings({bool showFeedback = true}) async {
    final storage = await LocalStorageClient.getInstance();
    await storage.setAwsProfile(_awsProfileController.text.trim());
    await storage.setAwsRegion(_awsRegionController.text.trim());
    await storage.setAwsClusterName(_awsClusterController.text.trim());
    await storage.setAwsAccountId(_awsAccountIdController.text.trim());
    await storage.setAwsSsoStartUrl(_awsSsoStartUrlController.text.trim());
    await storage.setAwsSsoRegion(_awsSsoRegionController.text.trim());

    if (!mounted || !showFeedback) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AWS settings saved'),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _refreshAwsCredentials() async {
    final profile = _awsProfileController.text.trim();
    final region = _awsRegionController.text.trim();
    final clusterName = _awsClusterController.text.trim();
    final accountId = _awsAccountIdController.text.trim();

    if (profile.isEmpty || region.isEmpty || clusterName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile, region, and cluster name are required.'),
        ),
      );
      return;
    }

    setState(() {
      _isAwsRefreshing = true;
    });

    try {
      await ref.read(kubernetesServiceProvider).refreshAwsSsoCredentials(
            profile: profile,
            region: region,
            clusterName: clusterName,
            accountId: accountId.isEmpty ? null : accountId,
          );
      await _saveAwsSettings(showFeedback: false);

      ref.invalidate(initializeProvider);
      refreshKubernetesResources(ref);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AWS credentials refreshed with profile "$profile".'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AWS credential refresh failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAwsRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            'Kubernetes Configuration',
            [
              _buildSetting(
                'Kubeconfig File',
                TextField(
                  controller: _kubeconfigController,
                  decoration: InputDecoration(
                    hintText: '~/.kube/config',
                    helperText:
                        'This path is used when initializing Kubernetes access.',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickKubeconfigFile,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Auto-refresh',
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    helperText:
                        'Refresh namespaces, pods, services, and configmaps',
                  ),
                  initialValue: settings.autoRefreshIntervalSeconds,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Off')),
                    DropdownMenuItem(value: 5, child: Text('Every 5 seconds')),
                    DropdownMenuItem(
                        value: 10, child: Text('Every 10 seconds')),
                    DropdownMenuItem(
                        value: 30, child: Text('Every 30 seconds')),
                    DropdownMenuItem(
                        value: 60, child: Text('Every 60 seconds')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setAutoRefreshInterval(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Default Namespace',
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings.defaultNamespace,
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('default')),
                    DropdownMenuItem(
                      value: 'kube-system',
                      child: Text('kube-system'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDefaultNamespace(value);
                      ref.read(selectedNamespaceProvider.notifier).state =
                          value;
                    }
                  },
                ),
              ),
            ],
          ),
          // const SizedBox(height: 32),
          // _buildSection(
          //   'AWS EKS Authentication',
          //   [
          //     _buildSetting(
          //       'AWS Profile',
          //       TextField(
          //         controller: _awsProfileController,
          //         decoration: const InputDecoration(
          //           labelText: 'Profile *',
          //           hintText: 'your-aws-profile',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     _buildSetting(
          //       'AWS Region',
          //       TextField(
          //         controller: _awsRegionController,
          //         decoration: const InputDecoration(
          //           labelText: 'Region *',
          //           hintText: 'your-region',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     _buildSetting(
          //       'EKS Cluster Name',
          //       TextField(
          //         controller: _awsClusterController,
          //         decoration: const InputDecoration(
          //           labelText: 'Cluster Name *',
          //           hintText: 'your-eks-cluster',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     _buildSetting(
          //       'AWS Account ID',
          //       TextField(
          //         controller: _awsAccountIdController,
          //         decoration: const InputDecoration(
          //           labelText: 'Account ID (Optional)',
          //           hintText: 'your-12-digit-account-id',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     _buildSetting(
          //       'SSO Start URL',
          //       TextField(
          //         controller: _awsSsoStartUrlController,
          //         decoration: const InputDecoration(
          //           labelText: 'SSO Start URL (Optional)',
          //           hintText: 'https://your-sso-start-url',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     _buildSetting(
          //       'SSO Region',
          //       TextField(
          //         controller: _awsSsoRegionController,
          //         decoration: const InputDecoration(
          //           labelText: 'SSO Region (Optional)',
          //           hintText: 'your-sso-region',
          //           border: OutlineInputBorder(),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(height: 12),
          //     Row(
          //       children: [
          //         OutlinedButton.icon(
          //           onPressed: _saveAwsSettings,
          //           icon: const Icon(Icons.save),
          //           label: const Text('Save AWS Settings'),
          //         ),
          //         const SizedBox(width: 12),
          //         FilledButton.icon(
          //           onPressed: _isAwsRefreshing ? null : _refreshAwsCredentials,
          //           icon: const Icon(Icons.login),
          //           label: Text(
          //             _isAwsRefreshing
          //                 ? 'Refreshing...'
          //                 : 'SSO Login & Update kubeconfig',
          //           ),
          //         ),
          //       ],
          //     ),
          //   ],
          // ),
          const SizedBox(height: 32),
          _buildSection(
            'Appearance',
            [
              _buildSetting(
                'Theme',
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<ThemeMode>(
                        style: SegmentedButton.styleFrom(
                          foregroundColor: _settingsControlForeground,
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFF55C77A),
                          side: BorderSide(
                            color: _settingsControlBorder,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (Set<ThemeMode> selection) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(selection.single);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSection(
            'Log Viewer',
            [
              _buildSetting(
                'Font Size',
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _settingsAccent,
                    inactiveTrackColor: _settingsControlBorder,
                    thumbColor: Colors.white,
                    overlayColor: _settingsAccent.withValues(alpha: 0.18),
                    valueIndicatorColor: _settingsAccent,
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Slider(
                    value: settings.logFontSize,
                    min: 10,
                    max: 20,
                    divisions: 10,
                    label: settings.logFontSize.round().toString(),
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setLogFontSize(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Max Lines',
                TextFormField(
                  initialValue: settings.maxLogLines.toString(),
                  decoration: const InputDecoration(
                    hintText: '1000',
                    border: OutlineInputBorder(),
                    helperText: 'Maximum number of log lines to keep in memory',
                  ),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      ref
                          .read(settingsProvider.notifier)
                          .setMaxLogLines(parsed);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Auto-scroll',
                SwitchListTile(
                  title: const Text('Enable auto-scroll by default'),
                  value: settings.autoScroll,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setAutoScroll(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              KeyboardListener(
                focusNode: _shortcutCaptureFocusNode,
                onKeyEvent: _handleShortcutCaptureKey,
                child: _buildSetting(
                  'Keyboard Shortcuts',
                  Column(
                    children: [
                      _buildShortcutCaptureRow(
                        label: 'Go line up',
                        action: _ShortcutAction.lineUp,
                        shortcut: settings.logNavigationUpShortcut,
                      ),
                      const SizedBox(height: 12),
                      _buildShortcutCaptureRow(
                        label: 'Go line down',
                        action: _ShortcutAction.lineDown,
                        shortcut: settings.logNavigationDownShortcut,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSection(
            'About',
            [
              const ListTile(
                title: Text('Author'),
                subtitle: Text('Bruno C. Penha'),
                trailing: Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('Version'),
                subtitle: FutureBuilder<String>(
                  future: AppConfig.getAppVersion(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? AppConfig.appVersionFallback,
                    );
                  },
                ),
                trailing: const Icon(Icons.info_outline),
              ),
              const ListTile(
                title: Text('License'),
                subtitle: Text('Apache-2.0 license'),
                trailing: Icon(Icons.description),
              ),
              ListTile(
                title: const Text('Releases'),
                subtitle: const Text('Get the last release on our GitHub page'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchInBrowser(toLaunch),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSetting(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildShortcutCaptureRow({
    required String label,
    required _ShortcutAction action,
    required String shortcut,
  }) {
    final isCapturing = _capturingShortcutAction == action.id;
    final buttonText = isCapturing ? 'Press a key...' : shortcutLabel(shortcut);

    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _startShortcutCapture(action),
              child: Text(buttonText),
            ),
          ),
        ),
      ],
    );
  }

  void _startShortcutCapture(_ShortcutAction action) {
    setState(() {
      _capturingShortcutAction = action.id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shortcutCaptureFocusNode.requestFocus();
    });
  }

  void _handleShortcutCaptureKey(KeyEvent event) {
    final action = _ShortcutAction.fromId(_capturingShortcutAction);
    if (action == null || event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _capturingShortcutAction = null;
      });
      return;
    }

    final shortcut = shortcutIdForKey(event.logicalKey);
    final conflictLabel = _shortcutConflictLabel(action, shortcut);
    if (conflictLabel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${shortcutLabel(shortcut)} is already used by $conflictLabel.',
          ),
        ),
      );
      setState(() {
        _capturingShortcutAction = null;
      });
      return;
    }

    _saveCapturedShortcut(action, shortcut);
  }

  String? _shortcutConflictLabel(_ShortcutAction action, String shortcut) {
    final settings = ref.read(settingsProvider);
    final capturedKey = keyForShortcut(shortcut);
    if (capturedKey == null) return null;

    final shortcuts = {
      _ShortcutAction.lineUp: settings.logNavigationUpShortcut,
      _ShortcutAction.lineDown: settings.logNavigationDownShortcut,
    };

    for (final entry in shortcuts.entries) {
      if (entry.key == action) continue;
      if (shortcutMatchesKey(entry.value, capturedKey)) {
        return entry.key.label;
      }
    }

    return null;
  }

  void _saveCapturedShortcut(_ShortcutAction action, String shortcut) {
    final notifier = ref.read(settingsProvider.notifier);

    switch (action) {
      case _ShortcutAction.lineUp:
        notifier.setLogNavigationUpShortcut(shortcut);
        break;
      case _ShortcutAction.lineDown:
        notifier.setLogNavigationDownShortcut(shortcut);
        break;
    }

    setState(() {
      _capturingShortcutAction = null;
    });
  }

  Color get _settingsControlForeground {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE8ECEF)
        : const Color(0xFF1F2328);
  }

  Color get _settingsControlBorder {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB8C0C7)
        : const Color(0xFF2D333B);
  }

  Color get _settingsAccent {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF5A8FD8)
        : const Color(0xFF2F72C4);
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../providers/settings_notifier.dart';
import '../../providers/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/kubernetes_provider.dart';
import '../../theme/app_text_styles.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _kubeconfigController = TextEditingController();
  final Uri toLaunch = Uri(
    scheme: 'https',
    host: 'github.com',
    path: 'brunopenha/kubegrandson/releases',
  );

  @override
  void dispose() {
    _kubeconfigController.dispose();
    super.dispose();
  }

  Future<void> _pickKubeconfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      //allowedExtensions: ['yaml', 'yml', 'config'],
      dialogTitle: 'Select Kubeconfig File',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _kubeconfigController.text = path;

      try {
        await ref
            .read(kubernetesServiceProvider)
            .initialize(kubeconfigPath: path);

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
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
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
                        value: 'kube-system', child: Text('kube-system'))
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
                          selectedForegroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                          selectedBackgroundColor:
                              Theme.of(context).colorScheme.secondary,
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
                Slider(
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
            ],
          ),
          const SizedBox(height: 32),
          _buildSection(
            'About',
            [
              ListTile(
                title: const Text('Author'),
                subtitle: const Text('Bruno C. Penha'),
                trailing: const Icon(Icons.info_outline),
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
              ListTile(
                title: const Text('License'),
                subtitle: const Text('Apache-2.0 license'),
                trailing: const Icon(Icons.description),
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
              //style: AppTextStyles.heading2,
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

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }
}

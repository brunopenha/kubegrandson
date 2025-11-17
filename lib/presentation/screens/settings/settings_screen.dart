import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

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

  @override
  void dispose() {
    _kubeconfigController.dispose();
    super.dispose();
  }

  Future<void> _pickKubeconfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'config'],
      dialogTitle: 'Select Kubeconfig File',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _kubeconfigController.text = path;

      try {
        await ref
            .read(kubernetesServiceProvider)
            .initialize(path);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                'Default Namespace',
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  value: 'default',
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('default')),
                    DropdownMenuItem(value: 'kube-system', child: Text('kube-system')),
                    DropdownMenuItem(value: 'all', child: Text('All Namespaces')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(selectedNamespaceProvider.notifier).state = value;
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
                          ref.read(themeModeProvider.notifier).toggleTheme();
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
                  value: 14,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  label: '14',
                  onChanged: (value) {
                    // TODO: Update font size preference
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Max Lines',
                TextField(
                  decoration: const InputDecoration(
                    hintText: '1000',
                    border: OutlineInputBorder(),
                    helperText: 'Maximum number of log lines to keep in memory',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),
              _buildSetting(
                'Auto-scroll',
                SwitchListTile(
                  title: const Text('Enable auto-scroll by default'),
                  value: true,
                  onChanged: (value) {
                    // TODO: Update preference
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
                title: const Text('Version'),
                subtitle: const Text('2.3.2'),
                trailing: const Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('License'),
                subtitle: const Text('MIT License'),
                trailing: const Icon(Icons.description),
              ),
              ListTile(
                title: const Text('GitHub'),
                subtitle: const Text('View source code'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: Open GitHub URL
                },
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
              style: AppTextStyles.heading2,
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
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
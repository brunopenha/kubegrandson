import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/kubernetes_provider.dart';
import 'presentation/providers/theme/app_colors.dart';
import 'presentation/widgets/common/loading_indicator.dart';

import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'app.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.init();

  // Desktop window configuration
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 520),
      minimumSize: Size(900, 480),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Kubegrandson - Kubernetes Json Log Viewer',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: KubeGrandsonApp()));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _levels = [
    'TRACE',
    'DEBUG',
    'INFO',
    'WARN',
    'ERROR',
    'FATAL',
    'UNK',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoRefreshProvider);

    final namespacesAsync = ref.watch(namespacesProvider);
    final selectedNamespace = ref.watch(selectedNamespaceProvider);
    final podsAsync = ref.watch(filteredPodsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _LegacyTitleBar(),
          _LegacyToolbar(
            namespacesAsync: namespacesAsync,
            selectedNamespace: selectedNamespace,
            onNamespaceChanged: (value) {
              if (value != null) {
                ref.read(selectedNamespaceProvider.notifier).state = value;
              }
            },
            onRefresh: () => refreshCurrentPods(ref),
          ),
          Expanded(
            child: podsAsync.when(
              data: (pods) {
                if (pods.isEmpty) {
                  return const _LegacyEmptyLogView();
                }

                return Container(
                  color: Colors.black,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: pods.length,
                    itemBuilder: (context, index) {
                      final pod = pods[index];

                      return _LegacyLogLine(
                        lineNumber: index + 1,
                        level: pod.phase.toUpperCase(),
                        message:
                            '[${pod.namespace}] Pod ${pod.name} - ${pod.statusText} | Restarts: ${pod.restartCount}',
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, _) => _LegacyLogLine(
                lineNumber: 1,
                level: 'ERROR',
                message: error.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyTitleBar extends StatelessWidget {
  const _LegacyTitleBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: const Color(0xffe9e9e9),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/app64.png',
            width: 16,
            height: 16,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.terminal,
              size: 16,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Kubegrandson - Kubernetes Json Log Viewer',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyToolbar extends StatelessWidget {
  final AsyncValue<List<String>> namespacesAsync;
  final String selectedNamespace;
  final ValueChanged<String?> onNamespaceChanged;
  final VoidCallback onRefresh;

  const _LegacyToolbar({
    required this.namespacesAsync,
    required this.selectedNamespace,
    required this.onNamespaceChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xff404040),
        border: Border(
          bottom: BorderSide(color: Color(0xff1d1d1d)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Namespace',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: namespacesAsync.when(
                    data: (namespaces) => DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedNamespace,
                        dropdownColor: const Color(0xff2b2b2b),
                        iconEnabledColor: Colors.white70,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        items: namespaces
                            .map(
                              (ns) => DropdownMenuItem(
                                value: ns,
                                child: Text(
                                  ns,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onNamespaceChanged,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Text(
                      'default',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...HomeScreen._levels.map(_LegacyLevelButton.new),
          const VerticalDivider(color: Color(0xff252525), width: 12),
          _ToolbarIcon(
            icon: Icons.delete_sweep,
            color: Colors.white70,
            tooltip: 'Clear logs',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.stop_circle,
            color: Colors.redAccent,
            tooltip: 'Stop',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.settings,
            color: Colors.white70,
            tooltip: 'Settings',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.arrow_upward,
            color: Colors.green,
            tooltip: 'Previous',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.arrow_downward,
            color: Colors.red,
            tooltip: 'Next',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.storage,
            color: Colors.white70,
            tooltip: 'Database',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.download,
            color: Colors.redAccent,
            tooltip: 'Export',
            onPressed: () {},
          ),
          _ToolbarIcon(
            icon: Icons.lock,
            color: Colors.orange,
            tooltip: 'Lock',
            onPressed: () {},
          ),
          const Spacer(),
          SizedBox(
            width: 230,
            height: 26,
            child: TextField(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              cursorColor: Colors.white70,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.black87,
                  size: 16,
                ),
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: const Color(0xff9da0a4),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyLevelButton extends StatelessWidget {
  final String label;

  const _LegacyLevelButton(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff313131),
        border: Border.all(color: const Color(0xff555555)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _LegacyEmptyLogView extends StatelessWidget {
  const _LegacyEmptyLogView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.topLeft,
      child: const _LegacyLogLine(
        lineNumber: 1,
        level: 'INFO',
        message: '[INFO] Waiting for Kubernetes logs...',
      ),
    );
  }
}

class _LegacyLogLine extends StatelessWidget {
  final int lineNumber;
  final String level;
  final String message;

  const _LegacyLogLine({
    required this.lineNumber,
    required this.level,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(level);

    return Container(
      height: 17,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xff171717), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$lineNumber',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xff168a17),
                fontSize: 10,
                fontFamily: 'RobotoMono',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${DateTime.now().toUtc().toIso8601String()} [$level] $message',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: color,
                fontSize: 10,
                height: 1,
                fontFamily: 'RobotoMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForLevel(String level) {
    final value = level.toLowerCase();

    if (value.contains('error') || value.contains('failed')) {
      return AppColors.error;
    }

    if (value.contains('warn') || value.contains('pending')) {
      return const Color(0xffffd84a);
    }

    if (value.contains('running') || value.contains('info')) {
      return const Color(0xffd7d7d7);
    }

    return const Color(0xffaaaaaa);
  }
}

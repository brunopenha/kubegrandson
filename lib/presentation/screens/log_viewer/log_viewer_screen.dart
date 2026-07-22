import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kubegrandson/domain/services/log_export_service.dart';
import 'package:kubegrandson/domain/services/log_import_service.dart';
import 'package:kubegrandson/presentation/providers/settings_notifier.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../providers/log_provider.dart';
import '../../providers/kubernetes_provider.dart';
import '../../shortcuts/log_navigation_shortcuts.dart';
import '../../providers/theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/log_syntax_highlighter.dart';
import 'widgets/log_list_view.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/filter_toolbar.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  final String namespace;
  final String podName;
  final List<String> podNames;
  final List<String> podGroupNames;
  final String? containerName;
  final String? initialImportPath;
  final String? initialSearchQuery;

  const LogViewerScreen({
    super.key,
    required this.namespace,
    required this.podName,
    this.podNames = const [],
    this.podGroupNames = const [],
    this.containerName,
    this.initialImportPath,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  double _jsonViewerWidth = 460.0;
  static const double _minJsonViewerWidth = 200.0;
  static const double _maxJsonViewerWidth = 900.0;
  late List<String> _activePodNames;
  bool _isRestartingLogStreaming = false;

  @override
  void initState() {
    super.initState();
    _activePodNames = List<String>.from(
      widget.podNames.isEmpty ? [widget.podName] : widget.podNames,
    )..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialSearchQuery = widget.initialSearchQuery?.trim();
      if (initialSearchQuery != null && initialSearchQuery.isNotEmpty) {
        ref
            .read(logProvider(_podKey).notifier)
            .setSearchQuery(initialSearchQuery);
      }
      final importPath = widget.initialImportPath;
      if (importPath == null) {
        _startLogStreaming();
      } else {
        _importJsonLogsFromPath(_podKey, importPath);
      }
    });
  }

  Future<void> _restartLogStreaming() async {
    if (_isRestartingLogStreaming) return;
    setState(() => _isRestartingLogStreaming = true);

    try {
      var podNames = List<String>.from(_activePodNames);
      if (widget.podGroupNames.isNotEmpty) {
        podNames = await _waitForReadyTargetPods();
      }

      if (!mounted) return;
      if (podNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No running pods found')),
        );
        return;
      }

      final previousPodNames = _activePodNames.toSet();
      final newPodNames = podNames
          .where((podName) => !previousPodNames.contains(podName))
          .toList();
      final notifier = ref.read(logProvider(_podKey).notifier);
      for (final podName in newPodNames) {
        notifier.addPodStartingMarker(podName);
      }

      setState(() => _activePodNames = podNames);
      if (newPodNames.isEmpty) {
        _startLogStreaming(preserveLogs: true);
      } else {
        notifier.addStreamingPods(
          namespace: widget.namespace,
          podNames: newPodNames,
          containerName: widget.containerName,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restarted log streaming for ${podNames.length} pod(s)',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restart log streaming: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestartingLogStreaming = false);
      }
    }
  }

  Future<List<String>> _waitForReadyTargetPods() async {
    final service = ref.read(kubernetesServiceProvider);
    final targetGroups = widget.podGroupNames.toSet();
    final previousPodNames = _activePodNames.toSet();
    var readyPodNames = <String>[];

    for (var attempt = 0; attempt < 30; attempt++) {
      final pods = await service.fetchPods(widget.namespace);
      readyPodNames = pods
          .where((pod) => targetGroups.contains(podGroupName(pod)))
          .where((pod) {
            if (!pod.isRunning) return false;
            final statuses = pod.containerStatuses;
            return statuses == null ||
                statuses.isEmpty ||
                statuses.every((status) => status.ready);
          })
          .map((pod) => pod.name)
          .toList()
        ..sort();

      final readyNames = readyPodNames.toSet();
      final samePods = readyNames.length == previousPodNames.length &&
          readyNames.containsAll(previousPodNames);
      final replacementsReady =
          readyPodNames.length >= previousPodNames.length &&
              readyNames.any((name) => !previousPodNames.contains(name));
      if (samePods || replacementsReady) return readyPodNames;

      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return const [];
    }

    return readyPodNames;
  }

  void _startLogStreaming({bool preserveLogs = false}) {
    final podKey = _podKey;
    ref.read(logProvider(podKey).notifier).startStreamingForPods(
          namespace: widget.namespace,
          podNames: _podNames,
          sourceLabel: widget.podName,
          containerName: widget.containerName,
          clearExistingLogs: !preserveLogs,
          markPodStoppedOnDone: true,
          retryInitialConnection: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final podKey = _podKey;
    final logState = ref.watch(logProvider(podKey));
    final settings = ref.watch(settingsProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleLogNavigationKey(
        event,
        podKey,
        settings.logNavigationUpShortcut,
        settings.logNavigationDownShortcut,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xff404040),
          foregroundColor: Colors.white,
          toolbarHeight: 42,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _logTitle,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.containerName != null)
                Text(
                  'Container: ${widget.containerName}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                    fontSize: settings.logFontSize,
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () {
              context.go('/');
            },
          ),
          actions: [
            IconButton(
              icon: _isRestartingLogStreaming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              color: Colors.white70,
              onPressed:
                  _isRestartingLogStreaming ? null : _restartLogStreaming,
              tooltip: 'Restart log streaming',
            ),
            IconButton(
              icon: Icon(
                logState.autoScroll ? Icons.pause : Icons.play_arrow,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () {
                ref.read(logProvider(podKey).notifier).toggleAutoScroll();
              },
              tooltip: logState.autoScroll
                  ? 'Pause Auto-scroll'
                  : 'Resume Auto-scroll',
            ),
            IconButton(
              icon: const Icon(Icons.pin_end, size: 20),
              color: Colors.white70,
              onPressed: () {
                ref.read(logProvider(podKey).notifier).addMarker();
              },
              tooltip: 'Add Log Marker',
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              color: Colors.redAccent,
              onPressed: () => _exportLogs(podKey),
              tooltip: 'Export Logs',
            ),
            IconButton(
              icon: const Icon(Icons.upload_file, size: 20),
              color: Colors.white70,
              onPressed: () => _importJsonLogs(podKey),
              tooltip: 'Open JSON Log File',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 20),
              color: Colors.white70,
              onPressed: () {
                ref.read(logProvider(podKey).notifier).clearLogs();
              },
              tooltip: 'Clear Logs',
            ),
          ],
        ),
        body: Column(
          children: [
            LogSearchBar(podKey: podKey),
            LogFilterToolbar(podKey: podKey),
            Expanded(
              child: Container(
                color: Colors.black,
                child: Row(
                  children: [
                    Expanded(
                      child: logState.isLoading && logState.logs.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : logState.error != null
                              ? Center(/* error UI */)
                              : LogListView(
                                  podKey: podKey,
                                  scrollController: _scrollController,
                                  positionsListener: _positionsListener,
                                ),
                    ),
                    if (logState.selectedLogEntry != null) ...[
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _jsonViewerWidth =
                                  (_jsonViewerWidth - details.delta.dx).clamp(
                                _minJsonViewerWidth,
                                _maxJsonViewerWidth,
                              );
                            });
                          },
                          child: SizedBox(
                            width: 6,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xff2b2b2b),
                              ),
                              child: Center(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xff444444),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: _jsonViewerWidth,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xff111111),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 36,
                                padding:
                                    const EdgeInsets.only(left: 12, right: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xff1b1b1b),
                                  border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xff2b2b2b)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Line: ${logState.selectedLogEntry!.lineNumber}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: settings.logFontSize,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: Colors.white70,
                                      tooltip: 'Close',
                                      onPressed: () {
                                        ref
                                            .read(logProvider(podKey).notifier)
                                            .selectLog(null);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText.rich(
                                    _selectedLogDetailSpan(
                                      logState.selectedLogEntry!,
                                      settings.logFontSize,
                                      logState.searchQuery,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildStatusBar(logState),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleLogNavigationKey(
    KeyEvent event,
    String podKey,
    String upShortcut,
    String downShortcut,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext != null &&
        focusedContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }

    if (shortcutMatchesKey(downShortcut, event.logicalKey)) {
      ref.read(logProvider(podKey).notifier).selectAdjacentLog(1);
      return KeyEventResult.handled;
    }

    if (shortcutMatchesKey(upShortcut, event.logicalKey)) {
      ref.read(logProvider(podKey).notifier).selectAdjacentLog(-1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildStatusBar(LogState logState) {
    final notifier = ref.read(logProvider(_podKey).notifier);
    final filteredCount = notifier.filteredLogs.length;
    final totalCount = logState.logs.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            logState.isLoading ? Icons.cloud_download : Icons.cloud_done,
            size: 16,
            color: logState.isLoading ? AppColors.info : AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            logState.isLoading ? 'Streaming...' : 'Connected',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(width: 24),
          Text(
            'Lines: $filteredCount${filteredCount != totalCount ? ' / $totalCount' : ''}',
            style: AppTextStyles.bodySmall,
          ),
          const Spacer(),
          Text(
            'Namespace: ${widget.namespace}',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _importJsonLogs(String podKey) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open JSON log file',
      type: FileType.custom,
      allowedExtensions: const ['json', 'jsonl', 'ndjson', 'log'],
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    await _importJsonLogsFromPath(podKey, path);
  }

  Future<void> _importJsonLogsFromPath(String podKey, String path) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final maxEntries = ref.read(settingsProvider).maxLogLines;

    messenger.showSnackBar(
      const SnackBar(content: Text('Importing JSON logs...')),
    );

    try {
      final logs = await LogImportService().parseJsonLogFilePath(
        path,
        maxEntries: maxEntries,
      );

      if (!mounted) return;
      await ref.read(logProvider(podKey).notifier).loadImportedLogs(logs);
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${logs.length} log lines')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to import JSON logs: $error')),
      );
    }
  }

  Future<void> _exportLogs(String podKey) async {
    final logs = ref.read(logProvider(podKey)).logs;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export')),
      );
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export logs',
      fileName: '${_safeFileName(_podNames.join('_'))}.log',
      type: FileType.custom,
      allowedExtensions: const ['log', 'txt'],
    );

    if (path == null) return;

    try {
      await LogExportService().exportToFile(
        path: path,
        logs: logs,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${logs.length} log lines')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export logs: $error')),
      );
    }
  }

  TextSpan _selectedLogDetailSpan(
    LogEntry log,
    double fontSize,
    String searchQuery,
  ) {
    final baseStyle = TextStyle(
      fontFamily: 'RobotoMono',
      color: Colors.white70,
      fontSize: fontSize,
    );

    final metadata = log.metadata;
    if (metadata == null) {
      final decoded = _tryDecodeJson(log.text);
      if (decoded != null) {
        return buildHighlightedJsonText(
          jsonText: const JsonEncoder.withIndent('  ').convert(decoded),
          searchQuery: searchQuery,
          baseStyle: baseStyle,
        );
      }

      return buildHighlightedShellText(
        shellText: log.text,
        searchQuery: searchQuery,
        baseStyle: baseStyle,
      );
    }

    return buildHighlightedJsonText(
      jsonText: const JsonEncoder.withIndent('  ').convert(metadata),
      searchQuery: searchQuery,
      baseStyle: baseStyle,
    );
  }

  Object? _tryDecodeJson(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_');
  }

  List<String> get _podNames =>
      widget.initialImportPath == null ? _activePodNames : widget.podNames;

  String get _logTitle {
    if (widget.initialImportPath != null) {
      return 'Logs: ${widget.podName}';
    }

    if (_podNames.length == 1) {
      return 'Logs: ${widget.podName}';
    }

    return 'Logs: ${widget.podName} (${_podNames.length} pods)';
  }

  String get _podKey {
    final identity = widget.podGroupNames.isEmpty
        ? _podNames.join(',')
        : widget.podGroupNames.join(',');
    return '${widget.namespace}/$identity';
  }
}

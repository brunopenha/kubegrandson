import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kubegrandson/domain/services/log_export_service.dart';
import 'package:kubegrandson/domain/services/log_import_service.dart';
import 'package:kubegrandson/presentation/providers/settings_notifier.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../providers/log_provider.dart';
import '../../providers/theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/log_list_view.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/filter_toolbar.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  final String namespace;
  final String podName;
  final List<String> podNames;
  final String? containerName;
  final String? initialImportPath;

  const LogViewerScreen({
    super.key,
    required this.namespace,
    required this.podName,
    this.podNames = const [],
    this.containerName,
    this.initialImportPath,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final importPath = widget.initialImportPath;
      if (importPath == null) {
        _startLogStreaming();
      } else {
        _importJsonLogsFromPath(_podKey, importPath);
      }
    });
  }

  void _startLogStreaming() {
    final podKey = _podKey;
    ref.read(logProvider(podKey).notifier).startStreamingForPods(
          namespace: widget.namespace,
          podNames: _podNames,
          sourceLabel: widget.podName,
          containerName: widget.containerName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final podKey = _podKey;
    final logState = ref.watch(logProvider(podKey));
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xff404040),
        foregroundColor: Colors.white,
        toolbarHeight: 42,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _podNames.length == 1
                  ? 'Logs: ${_podNames.first}'
                  : 'Logs: ${_podNames.length} pods',
              style: const TextStyle(fontSize: 12),
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
                                  bottom: BorderSide(color: Color(0xff2b2b2b)),
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
                                child: SelectableText(
                                  _formatSelectedLogDetails(
                                    logState.selectedLogEntry!,
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    color: Colors.white70,
                                    fontSize: settings.logFontSize,
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
    );
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

  String _formatSelectedLogDetails(LogEntry log) {
    if (log.metadata != null) {
      return const JsonEncoder.withIndent('  ').convert(log.metadata);
    }

    return log.text;
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_');
  }

  List<String> get _podNames =>
      widget.podNames.isEmpty ? [widget.podName] : widget.podNames;

  String get _podKey => '${widget.namespace}/${_podNames.join(',')}';
}

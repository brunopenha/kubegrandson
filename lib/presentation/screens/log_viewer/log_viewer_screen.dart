import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  const LogViewerScreen({
    super.key,
    required this.namespace,
    required this.podName,
    this.podNames = const [],
    this.containerName,
  });

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLogStreaming();
    });
  }

  void _startLogStreaming() {
    final podKey = _podKey;
    ref.read(logProvider(podKey).notifier).startStreamingForPods(
          namespace: widget.namespace,
          podNames: _podNames,
          containerName: widget.containerName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final podKey = _podKey;
    final logState = ref.watch(logProvider(podKey));

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
                  fontSize: 10,
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
            icon: const Icon(Icons.download, size: 20),
            color: Colors.redAccent,
            onPressed: () {
              // TODO: Export logs
            },
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 20),
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
                  if (logState.selectedLogEntry?.metadata != null)
                    SizedBox(
                      width: 460,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xff111111),
                          border: Border(
                            left: BorderSide(color: Color(0xff2b2b2b)),
                          ),
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
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    color: Colors.white70,
                                    tooltip: 'Close JSON',
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
                                  const JsonEncoder.withIndent('  ').convert(
                                      logState.selectedLogEntry!.metadata),
                                  style: const TextStyle(
                                    fontFamily: 'RobotoMono',
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  List<String> get _podNames =>
      widget.podNames.isEmpty ? [widget.podName] : widget.podNames;

  String get _podKey => '${widget.namespace}/${_podNames.join(',')}';
}

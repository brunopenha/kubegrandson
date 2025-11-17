import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String? containerName;

  const LogViewerScreen({
    super.key,
    required this.namespace,
    required this.podName,
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
    final podKey = '${widget.namespace}/${widget.podName}';
    ref.read(logProvider(podKey).notifier).startStreaming(
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: widget.containerName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final podKey = '${widget.namespace}/${widget.podName}';
    final logState = ref.watch(logProvider(podKey));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logs: ${widget.podName}'),
            if (widget.containerName != null)
              Text(
                'Container: ${widget.containerName}',
                style: AppTextStyles.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              logState.autoScroll ? Icons.pause : Icons.play_arrow,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ref.read(logProvider(podKey).notifier).toggleAutoScroll();
            },
            tooltip: logState.autoScroll ? 'Pause Auto-scroll' : 'Resume Auto-scroll',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Export logs
            },
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
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
            child: logState.isLoading && logState.logs.isEmpty
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : logState.error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading logs',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    logState.error!,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startLogStreaming,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : LogListView(
              podKey: podKey,
              scrollController: _scrollController,
              positionsListener: _positionsListener,
            ),
          ),
          _buildStatusBar(logState),
        ],
      ),
    );
  }

  Widget _buildStatusBar(LogState logState) {
    final notifier = ref.read(logProvider('${widget.namespace}/${widget.podName}').notifier);
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
}
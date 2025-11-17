import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../providers/log_provider.dart';
import '../../../providers/theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class LogListView extends ConsumerStatefulWidget {
  final String podKey;
  final ItemScrollController scrollController;
  final ItemPositionsListener positionsListener;

  const LogListView({
    super.key,
    required this.podKey,
    required this.scrollController,
    required this.positionsListener,
  });

  @override
  ConsumerState<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends ConsumerState<LogListView> {
  int? _selectedLineIndex;

  @override
  void initState() {
    super.initState();
    widget.positionsListener.itemPositions.addListener(_onScroll);
  }

  void _onScroll() {
    final logState = ref.read(logProvider(widget.podKey));
    if (logState.autoScroll) {
      final positions = widget.positionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        final lastVisibleIndex = positions
            .where((position) => position.itemTrailingEdge > 0)
            .reduce((a, b) => a.index > b.index ? a : b)
            .index;

        final notifier = ref.read(logProvider(widget.podKey).notifier);
        final totalLogs = notifier.filteredLogs.length;

        if (lastVisibleIndex >= totalLogs - 5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.scrollController.isAttached) {
              widget.scrollController.scrollTo(
                index: totalLogs - 1,
                duration: const Duration(milliseconds: 300),
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logNotifier = ref.read(logProvider(widget.podKey).notifier);
    final logs = logNotifier.filteredLogs;

    if (logs.isEmpty) {
      return const Center(
        child: Text('No logs available'),
      );
    }

    return ScrollablePositionedList.builder(
      itemCount: logs.length,
      itemScrollController: widget.scrollController,
      itemPositionsListener: widget.positionsListener,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isSelected = _selectedLineIndex == index;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedLineIndex = isSelected ? null : index;
            });
          },
          onSecondaryTap: () {
            _showContextMenu(context, log.text);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: isSelected
                ? AppColors.primary.withOpacity(0.2)
                : index.isEven
                ? Colors.transparent
                : AppColors.backgroundDark.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${log.lineNumber}',
                    style: AppTextStyles.monospaceSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    log.text,
                    style: AppTextStyles.monospaceLarge.copyWith(
                      color: _getLogColor(log.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getLogColor(String logText) {
    final lowerText = logText.toLowerCase();
    if (lowerText.contains('error') || lowerText.contains('fatal')) {
      return AppColors.error;
    } else if (lowerText.contains('warn')) {
      return AppColors.warning;
    } else if (lowerText.contains('info')) {
      return AppColors.info;
    } else if (lowerText.contains('debug')) {
      return AppColors.textSecondary;
    }
    return AppColors.textPrimary;
  }

  void _showContextMenu(BuildContext context, String text) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Copy'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
          },
        ),
        PopupMenuItem(
          child: const Text('Copy All'),
          onTap: () {
            final notifier = ref.read(logProvider(widget.podKey).notifier);
            final allLogs = notifier.filteredLogs
                .map((log) => log.text)
                .join('\n');
            Clipboard.setData(ClipboardData(text: allLogs));
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.positionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }
}
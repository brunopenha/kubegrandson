import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kubegrandson/presentation/providers/settings_notifier.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../providers/log_provider.dart';
import 'log_syntax_highlighter.dart';

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
  bool _autoScrollScheduled = false;
  int _pendingScrollIndex = -1;
  double _pendingScrollAlignment = 0.9;

  void _scheduleJumpTo(int index, {double alignment = 0.9}) {
    if (index < 0) return;
    _pendingScrollIndex = index;
    _pendingScrollAlignment = alignment;
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted || !widget.scrollController.isAttached) return;

      widget.scrollController.jumpTo(
        index: _pendingScrollIndex,
        alignment: _pendingScrollAlignment,
      );
    });
  }

  List<ItemPosition> get _visiblePositions =>
      widget.positionsListener.itemPositions.value.toList();

  bool _isIndexVisible(int index) {
    return _visiblePositions.any(
      (position) =>
          position.index == index &&
          position.itemLeadingEdge >= 0 &&
          position.itemTrailingEdge <= 1,
    );
  }

  bool _wasAtBottom(int lastIndex) {
    if (lastIndex < 0) return true;

    final positions = _visiblePositions;
    if (positions.isEmpty) return true;

    return positions.any(
      (position) =>
          position.index == lastIndex &&
          position.itemLeadingEdge < 1 &&
          position.itemTrailingEdge <= 1.05,
    );
  }

  void _scrollSelectedIntoView(int index) {
    if (index < 0 || _isIndexVisible(index)) return;

    final positions = _visiblePositions;
    if (positions.isEmpty) {
      _scheduleJumpTo(index, alignment: 0.9);
      return;
    }

    ItemPosition? selectedPosition;
    for (final position in positions) {
      if (position.index == index) {
        selectedPosition = position;
        break;
      }
    }
    if (selectedPosition != null) {
      if (selectedPosition.itemLeadingEdge < 0) {
        _scheduleJumpTo(index, alignment: 0);
      } else if (selectedPosition.itemTrailingEdge > 1) {
        _scheduleJumpTo(index, alignment: 0.9);
      }
      return;
    }

    final indexes = positions.map((position) => position.index);
    final firstVisibleIndex = indexes.reduce((a, b) => a < b ? a : b);
    final lastVisibleIndex = indexes.reduce((a, b) => a > b ? a : b);

    if (index < firstVisibleIndex) {
      _scheduleJumpTo(index, alignment: 0);
    } else if (index > lastVisibleIndex) {
      _scheduleJumpTo(index, alignment: 0.9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logNotifier = ref.read(logProvider(widget.podKey).notifier);
    final logState = ref.watch(logProvider(widget.podKey));
    final logs = logNotifier.filteredLogs;
    final settings = ref.watch(settingsProvider);

    ref.listen(logProvider(widget.podKey), (previous, next) {
      final selected = next.selectedLogEntry;
      if (selected != null && selected != previous?.selectedLogEntry) {
        final index = ref
            .read(logProvider(widget.podKey).notifier)
            .filteredLogs
            .indexOf(selected);
        _scrollSelectedIntoView(index);
        return;
      }

      final resumed = previous?.autoScroll == false && next.autoScroll;
      final receivedLogs = !identical(previous?.logs, next.logs);
      final wasAtBottom = previous == null ||
          _wasAtBottom(filteredLogsForState(previous).length - 1);
      if (next.autoScroll && (resumed || (receivedLogs && wasAtBottom))) {
        final lastIndex =
            ref.read(logProvider(widget.podKey).notifier).filteredLogs.length -
                1;
        _scheduleJumpTo(lastIndex);
      }
    });

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
        final selected = logState.selectedLogEntry;
        final isSelected = selected == log;
        void toggleSelection() {
          ref
              .read(logProvider(widget.podKey).notifier)
              .selectLog(isSelected ? null : log);
        }

        return InkWell(
          onTap: toggleSelection,
          onSecondaryTap: () {
            _showContextMenu(context, log.text);
          },
          child: Container(
            height: 17,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xff17395c) : Colors.black,
              border: const Border(
                bottom: BorderSide(
                  color: Color(0xff171717),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    '${log.lineNumber}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: const Color(0xff168a17),
                      fontSize: settings.logFontSize,
                      height: 1,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (logState.showPodNames) ...[
                  SizedBox(
                    width: 340,
                    child: Tooltip(
                      message: log.source ?? '',
                      child: Text(
                        log.source ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xff7dcfff),
                          fontSize: settings.logFontSize,
                          height: 1,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: SelectableText.rich(
                    _highlightedLogLine(
                      log,
                      logState.showTimestamps,
                      logState.searchQuery,
                    ),
                    maxLines: 1,
                    onTap: toggleSelection,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TextSpan _highlightedLogLine(
    LogEntry log,
    bool showTimestamp,
    String searchQuery,
  ) {
    final baseStyle = TextStyle(
      color: logLevelColor(logLevelForDisplay(log)),
      fontSize: ref.watch(settingsProvider).logFontSize,
      height: 1,
      fontFamily: 'RobotoMono',
    );

    return buildHighlightedLogLine(
      log: log,
      showTimestamp: showTimestamp,
      searchQuery: searchQuery,
      baseStyle: baseStyle,
    );
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
            final allLogs =
                notifier.filteredLogs.map((log) => log.text).join('\n');
            Clipboard.setData(ClipboardData(text: allLogs));
          },
        ),
      ],
    );
  }
}

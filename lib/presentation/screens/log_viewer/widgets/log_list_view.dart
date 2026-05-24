import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kubegrandson/presentation/providers/settings_notifier.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../providers/log_provider.dart';

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
    final logState = ref.watch(logProvider(widget.podKey));
    final logs = logNotifier.filteredLogs;
    final settings = ref.watch(settingsProvider);

    if (logs.isEmpty) {
      return const Center(
        child: Text('No logs available'),
      );
    }

    ref.listen(logProvider(widget.podKey), (previous, next) {
      final selected = next.selectedLogEntry;
      if (selected == null) return;

      final index = ref
          .read(logProvider(widget.podKey).notifier)
          .filteredLogs
          .indexOf(selected);

      if (index < 0) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController.isAttached) {
          widget.scrollController.scrollTo(
            index: index,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    });

    return ScrollablePositionedList.builder(
      itemCount: logs.length,
      itemScrollController: widget.scrollController,
      itemPositionsListener: widget.positionsListener,
      itemBuilder: (context, index) {
        final log = logs[index];
        final selected = logState.selectedLogEntry;
        final isSelected = selected == log;

        return InkWell(
          onTap: () {
            ref
                .read(logProvider(widget.podKey).notifier)
                .selectLog(isSelected ? null : log);
          },
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
                if (log.source != null) ...[
                  SizedBox(
                    width: 180,
                    child: Text(
                      log.source!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xff7aa2f7),
                        fontSize: settings.logFontSize,
                        height: 1,
                        fontFamily: 'RobotoMono',
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLogLine(LogEntry log, bool showTimestamp) {
    final message = log.metadata != null ? jsonEncode(log.metadata) : log.text;
    if (!showTimestamp) return message;

    return '${log.timestamp.toIso8601String()} $message';
  }

  TextSpan _highlightedLogLine(
    LogEntry log,
    bool showTimestamp,
    String searchQuery,
  ) {
    final text = _formatLogLine(log, showTimestamp);
    final baseStyle = TextStyle(
      color: _getLogColor(log.text),
      fontSize: ref.watch(settingsProvider).logFontSize,
      height: 1,
      fontFamily: 'RobotoMono',
    );

    if (searchQuery.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      final end = index + searchQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(index, end),
          style: baseStyle.copyWith(
            color: Colors.black,
            backgroundColor: const Color(0xffffd84a),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = end;
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  Color _getLogColor(String logText) {
    final lowerText = logText.toLowerCase();
    if (lowerText.contains('error') || lowerText.contains('fatal')) {
      return const Color(0xffff5f56);
    } else if (lowerText.contains('warn')) {
      return const Color(0xffffd84a);
    } else if (lowerText.contains('info') || lowerText.contains('note')) {
      return const Color(0xffd7d7d7);
    } else if (lowerText.contains('debug')) {
      return const Color(0xff8ab4f8);
    }
    return const Color(0xffbdbdbd);
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

  @override
  void dispose() {
    widget.positionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/log_provider.dart';
import '../../../providers/theme/app_colors.dart';
import '../../../widgets/common/tab_pill.dart';

enum LogLevelFilter implements TabPillButtonConfig {
  all('All', null, Icons.list),
  trace('Trace', 'trace-level', Icons.bug_report_sharp),
  debug('Debug', 'debug-level', Icons.bug_report_outlined),
  info('Info', 'info-level', Icons.info),
  warning('Warning', 'warning-level', Icons.warning),
  error('Error', 'error-level', Icons.error),
  fatal('Fatal', 'fatal-level', Icons.error_outline);

  final String _text;
  final String? _styleClass;
  final IconData? _icon;

  const LogLevelFilter(this._text, this._styleClass, this._icon);

  @override
  String get text => _text;

  @override
  String? get styleClass => _styleClass;

  @override
  IconData? get icon => _icon;
}

class LogFilterToolbar extends ConsumerWidget {
  final String podKey;

  const LogFilterToolbar({
    super.key,
    required this.podKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider(podKey));
    final logNotifier = ref.read(logProvider(podKey).notifier);
    final selectedFilters = _selectedFilters(logState);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Log Level:',
            style: TextStyle(color: Color(0xFFE3E6E8)),
          ),
          const SizedBox(width: 12),
          TabPill<LogLevelFilter>(
            buttons: LogLevelFilter.values,
            selectedButtons: selectedFilters,
            orientation: TabPillOrientation.horizontal,
            minButtonWidth: 50,
            onButtonToggled: (key, selected) {
              switch (key) {
                case LogLevelFilter.trace:
                  logNotifier.setTraceFilter(selected);
                  break;
                case LogLevelFilter.debug:
                  logNotifier.setDebugFilter(selected);
                  break;
                case LogLevelFilter.warning:
                  logNotifier.setWarnFilter(selected);
                  break;
                case LogLevelFilter.error:
                  logNotifier.setErrorFilter(selected);
                  break;
                case LogLevelFilter.fatal:
                  logNotifier.setFatalFilter(selected);
                  break;
                case LogLevelFilter.info:
                  logNotifier.setInfoFilter(selected);
                  break;
                case LogLevelFilter.all:
                  logNotifier.clearLevelFilters();
                  break;
              }
            },
          ),
          const Spacer(),
          Checkbox(
            value: logState.showPodNames,
            onChanged: (value) {
              logNotifier.setShowPodNames(value ?? false);
            },
          ),
          const Text(
            'Show Pod Name',
            style: TextStyle(color: Color(0xFFE3E6E8)),
          ),
          const SizedBox(width: 16),
          Checkbox(
            value: logState.showTimestamps,
            onChanged: (value) {
              logNotifier.setShowTimestamps(value ?? false);
            },
          ),
          const Text(
            'Show Timestamps',
            style: TextStyle(color: Color(0xFFE3E6E8)),
          ),
        ],
      ),
    );
  }

  Set<LogLevelFilter> _selectedFilters(LogState logState) {
    final selected = <LogLevelFilter>{};
    if (logState.traceOnly) selected.add(LogLevelFilter.trace);
    if (logState.debugOnly) selected.add(LogLevelFilter.debug);
    if (logState.infoOnly) selected.add(LogLevelFilter.info);
    if (logState.warnOnly) selected.add(LogLevelFilter.warning);
    if (logState.errorOnly) selected.add(LogLevelFilter.error);
    if (logState.fatalOnly) selected.add(LogLevelFilter.fatal);

    if (selected.isEmpty) return {LogLevelFilter.all};
    return selected;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme/app_colors.dart';
import '../../../widgets/common/tab_pill.dart';

enum LogLevelFilter implements TabPillButtonConfig {
  all('All', null, Icons.list),
  error('Error', 'error-level', Icons.error),
  warning('Warning', 'warning-level', Icons.warning),
  info('Info', 'info-level', Icons.info),
  debug('Debug', 'debug-level', Icons.bug_report);

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
          const Text('Log Level:'),
          const SizedBox(width: 12),
          TabPill<LogLevelFilter>(
            buttons: LogLevelFilter.values,
            orientation: TabPillOrientation.horizontal,
            minButtonWidth: 50,
            onButtonToggled: (key, selected) {
              // TODO: Implement log level filtering
              print('Filter: ${key.text} - $selected');
            },
          ),
          const Spacer(),
          Checkbox(
            value: false, // TODO: Connect to provider
            onChanged: (value) {
              // TODO: Toggle timestamp display
            },
          ),
          const Text('Show Timestamps'),
        ],
      ),
    );
  }
}
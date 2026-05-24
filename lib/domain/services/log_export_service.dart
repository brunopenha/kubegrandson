import 'dart:io';

import '../../presentation/providers/log_provider.dart';

class LogExportService {
  String format(List<LogEntry> logs) {
    return logs.map((log) => log.text).join('\n');
  }

  Future<void> exportToFile({
    required String path,
    required List<LogEntry> logs,
  }) async {
    await File(path).writeAsString(format(logs));
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/log_export_service.dart';
import 'package:kubegrandson/presentation/providers/log_provider.dart';

LogEntry _entry(String text, int lineNumber) {
  return LogEntry(
    text: text,
    timestamp: DateTime(2026),
    lineNumber: lineNumber,
  );
}

void main() {
  test('format exports one log line per entry', () {
    final service = LogExportService();

    final output = service.format([
      _entry('first log', 1),
      _entry('second log', 2),
    ]);

    expect(output, 'first log\nsecond log');
  });

  test('exportToFile writes formatted logs to disk', () async {
    final service = LogExportService();
    final file =
        File('${Directory.systemTemp.path}/kubegrandson_export_test.log');
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    await service.exportToFile(
      path: file.path,
      logs: [
        _entry('line one', 1),
        _entry('line two', 2),
      ],
    );

    expect(await file.readAsString(), 'line one\nline two');
  });
}

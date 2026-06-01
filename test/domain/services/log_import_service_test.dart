import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/log_import_service.dart';

void main() {
  test(
    'Parses JSON array log file into LogEntry objects',
    () {
      final service = LogImportService();

      final logs = service.parseJsonLogFile('''
[
  {
    "timestamp": "2026-05-24T10:00:00Z",
    "level": "info",
    "message": "Application started",
    "source": "api"
  }
]
''');

      expect(logs, hasLength(1));
      expect(logs.single.text, contains('Application started'));
      expect(logs.single.level, 'info');
      expect(logs.single.source, 'api');
    },
  );

  test(
    'Parses JSON lines log file into LogEntry objects',
    () {
      final service = LogImportService();

      final logs = service.parseJsonLogFile('''
{"timestamp":"2026-05-24T10:00:00Z","level":"info","message":"started"}
{"timestamp":"2026-05-24T10:01:00Z","level":"error","message":"failed"}
''');

      expect(logs, hasLength(2));
      expect(logs.first.level, 'info');
      expect(logs.last.level, 'error');
    },
  );

  test('Parses multi-line JSON object as one log entry', () {
    final service = LogImportService();

    final logs = service.parseJsonLogFile('''
{
  "timestamp": "2026-05-24T10:00:00Z",
  "level": "warn",
  "message": "single formatted object"
}
''');

    expect(logs, hasLength(1));
    expect(logs.single.text, 'single formatted object');
    expect(logs.single.level, 'warn');
  });

  test('Parses JSON object containing a logs array', () {
    final service = LogImportService();

    final logs = service.parseJsonLogFile('''
{
  "logs": [
    {
      "timestamp": "2026-05-24T10:00:00Z",
      "level": "info",
      "message": "first wrapped log"
    },
    {
      "timestamp": "2026-05-24T10:01:00Z",
      "level": "error",
      "message": "second wrapped log"
    }
  ]
}
''');

    expect(logs, hasLength(2));
    expect(logs.first.text, 'first wrapped log');
    expect(logs.last.text, 'second wrapped log');
  });

  test('Keeps invalid JSON lines as raw log entries', () {
    final service = LogImportService();

    final logs = service.parseJsonLogFile('''
[2026-05-24T21:17:37.529303] INFO exec -a "java" java -XX:MaxRAMPercentage=...
{"timestamp":"2026-05-24T21:18:00Z","level":"info","message":"valid json"}
plain text log line
''');

    expect(logs, hasLength(3));
    expect(logs.first.text, contains('INFO exec'));
    expect(logs.first.level, 'info');
    expect(logs[1].metadata, isNotNull);
    expect(logs[1].text, 'valid json');
    expect(logs.last.text, 'plain text log line');
  });
}

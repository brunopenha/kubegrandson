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
    skip: 'TODO(json-log-import): remove skip when implementing import',
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
    skip: 'TODO(json-log-import): remove skip when implementing import',
  );
}

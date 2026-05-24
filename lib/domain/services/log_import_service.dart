import '../../presentation/providers/log_provider.dart';

class LogImportService {
  List<LogEntry> parseJsonLogFile(String content) {
    // TODO(json-log-import): Implement JSON log import here.
    //
    // Suggested first formats to support:
    // 1. JSON array:
    //    [{"timestamp":"...","level":"info","message":"started"}]
    // 2. JSON lines:
    //    {"timestamp":"...","level":"info","message":"started"}
    //    {"timestamp":"...","level":"error","message":"failed"}
    //
    // Convert each parsed object into LogEntry and then feed LogNotifier.replaceLogs.
    throw UnimplementedError('JSON log import is not implemented yet');
  }
}
